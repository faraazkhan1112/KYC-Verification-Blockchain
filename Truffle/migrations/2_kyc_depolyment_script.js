const KYC = artifacts.require("kyc");

module.exports = function (deployer) {
	deployer.deploy(KYC);
};
