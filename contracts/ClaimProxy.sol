pragma solidity ^0.4.24;

import "./IdentityProxy.sol";
import "./ERC735.sol";


contract ClaimProxy is ERC735 {

  event Log(bytes data);
  event Log(bytes32 indexed data);

  mapping (bytes32 => Claim) claims;
  mapping (uint256 => Claim) pendingClaims;
  mapping (uint256 => bytes32[]) claimIdsByTopic;
  uint256 private claimRequestId = 0;

  IdentityProxy public identityAddress;

  constructor() {
    identityAddress = new IdentityProxy(1 , msg.sender);
  }

  function getClaim(bytes32 _claimId) public constant returns(uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri) {
    Claim claim = claims[_claimId];
    return (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
  }

  function getClaimIdsByTopic(uint256 _topic) public constant returns(bytes32[] claimIds) {
    return claimIdsByTopic[_topic];
  }

  //bytes32 claimId = keccak256(issuer_address, topic);
  function addPendingClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes _signature, bytes _data, string _uri) internal returns (uint256) {

    bytes memory txData = abi.encodeWithSignature("addClaim(uint256,uint256,address,bytes,bytes,string)", _topic,_scheme, _issuer, _signature, _data, _uri);
    return identityAddress.addExecution(address(this), 0, txData);
    emit Log(txData);
  }
  /* This SHOULD create a pending claim, which SHOULD to
  be approved or rejected by n of m approve calls from keys of purpose 1
  if its self claim, no approve is required.
  Returns claimRequestId: COULD be send to the approve function, to approve or reject this claim.
  Triggers if the claim is new Event and approval process exists: ClaimRequested
  Triggers if the claim is new Event and is added: ClaimAdded
  Triggers if the claim index existed Event: ClaimChanged  */
  function addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes _signature, bytes _data, string _uri) public returns (uint256 claimRequestId) {

    uint256 id = addPendingClaim(_topic, _scheme, _issuer, _signature, _data, _uri);
    ClaimRequested(id, _topic, _scheme, _issuer, _signature, _data, _uri);

     bytes32 claimId = keccak256(_issuer, _topic);
    //No approval for self claim, else approval process decide the addition of claims
    if (msg.sender == address(identityAddress) || (identityAddress.keyHasPurpose(keccak256(msg.sender), 1))) {
      claims[claimId].topic = _topic;
      claims[claimId].scheme = _scheme;
      claims[claimId].issuer = _issuer;
      claims[claimId].signature = _signature;
      claims[claimId].data = _data;
      claims[claimId].uri = _uri;
      ClaimAdded(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
      return id;
    }
    return id;
  }
  //function changeClaim(bytes32 _claimId, uint256 _topic, uint256 _scheme, address _issuer, bytes _signature, bytes _data, string _uri) returns (bool success);
  //function removeClaim(bytes32 _claimId) public returns (bool success);
}
