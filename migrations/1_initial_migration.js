var Identity = artifacts.require("./ClaimProxy.sol");

module.exports = function(deployer) {
  deployer.deploy(Identity);
};
