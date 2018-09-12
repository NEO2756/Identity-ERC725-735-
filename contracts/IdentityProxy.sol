pragma solidity ^0.4.24;

import "./ERC725.sol";

contract IdentityProxy is ERC725 {

  //we will move this in ERC725.sol afterwards.
  uint256 constant MANAGEMENT_KEY = 1;
  uint256 constant ACTION_KEY = 2;
  uint256 constant CLAIM_SIGNER_KEY = 3;
  uint256 constant ENCRYPTION_KEY = 4;
  uint256 constant MAX_PURPOSE_LENGTH = 4;

  uint256 private multisigRequirement;

  event ExecutionFailed(uint256, string);


  struct transaction {
    address to;
    bytes data;
    uint256 value;
    uint256 requirement;
    bool executed;
  }

  mapping(bytes32 => Key) private keys;
  mapping(uint256 => bytes32[]) keysByPurpose;
  mapping(uint256 => transaction) transactions;
  address public identity;

  uint256 private executionId = 0;


  constructor(uint req, address owner) {
    bytes32 key = keccak256(owner);
    keys[key].key = key;
    keys[key].purposes.push(MANAGEMENT_KEY);
    keys[key].keyType = 1;
    multisigRequirement = req;
    emit KeyAdded(key, MANAGEMENT_KEY, 1);
  }

  function getKey(bytes32 _key) public constant returns(uint256[] purposes, uint256 keyType, bytes32 key) {
    return (keys[_key].purposes, keys[_key].keyType, keys[_key].key);
  }

  function keyHasPurpose(bytes32 _key, uint256 purpose) constant returns(bool exists) {
    for (uint256 i = 0 ; i < keys[_key].purposes.length; i++) {
      if (keys[_key].purposes[i] <= purpose) return true;
    }
    return false;
  }

  function getKeysByPurpose(uint256 _purpose) public constant returns(bytes32[] keys) {
    return keysByPurpose[_purpose];
  }

  function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) public returns (bool success) {
    require(_key != 0);
    require(_purpose <= MAX_PURPOSE_LENGTH);

    //Only MANAGEMENT_KEY holder can directly add the key.
    if (msg.sender != address(this)) {
      require(keyHasPurpose(keccak256(msg.sender), MANAGEMENT_KEY));
    }

    keys[_key].key = _key;
    keys[_key].purposes.push(_purpose);
    keys[_key].keyType = _keyType;

    KeyAdded(_key, _purpose,_keyType);
    return true;
  }

  function addExecution(address _to, uint256 _value, bytes _data) public returns (uint256) {
    //transactions[executionId].nonce++;
    transactions[executionId].to = _to;
    transactions[executionId].value = _value;
    transactions[executionId].data = _data;
    transactions[executionId].requirement = 0; //lets assume 1 of 1 multisig right now.
    transactions[executionId].executed = false;
    executionId++;
    return executionId - 1;
  }

  function execute(address _to, uint256 _value, bytes _data) public returns (uint256 executionId) {
    //call when execute is successfuly called
    bool status = false;
    executionId = addExecution(_to, _value, _data);
    ExecutionRequested(executionId, _to, _value, _data);

    if (keyHasPurpose(keccak256(msg.sender), MANAGEMENT_KEY)) { // || keyHasPurpose(keccak256(msg.sender), ACTION_KEY)) {
      status = approve(executionId, true);
    }
    return executionId; //return execution id for someone listening to execution requested event.
  }

  /* Approves an execution or claim addition.
  This SHOULD require n of m approvals of keys purpose 1, if the _to of
  the execution is the identity contract itself, to successfull approve an execution.
  And COULD require n of m approvals of keys purpose 2, if the _to of the execution is another
  contract, to successfull approve an execution. */

  function approve(uint256 _id, bool _approve) public returns (bool success) {

    bool status = false;
    emit Approved(_id, _approve); //must be called when approve is successfully called
    require (transactions[_id].executed == false);
    if (_approve) {
      if (transactions[_id].to == address(this)) {  //Action on identity contract
        require(keyHasPurpose(keccak256(msg.sender), MANAGEMENT_KEY)); //require purpose = 1
        transactions[_id].requirement++;
        if (transactions[_id].requirement >= multisigRequirement) {
          status = transactions[_id].to.call.value(transactions[_id].value)(transactions[_id].data);
          transactions[_id].executed = true;
        }
        return true; //need more approvals.
        } else if (keyHasPurpose(keccak256(msg.sender), ACTION_KEY)) { //anything else u atleast need ACTION key
          transactions[_id].requirement++;
          status = transactions[_id].to.call.value(transactions[_id].value)(transactions[_id].data);
          transactions[_id].executed = true;
        }
      }
      else //Reject claim addition to this identity
      {
        status = false;
        transactions[_id].executed = true;
      }
      if (status) {
        Executed(_id, transactions[_id].to, transactions[_id].value, transactions[_id].data);
      }
      return status;
    }
  }
