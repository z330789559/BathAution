var NFTAuction = artifacts.require("./NFTAuction.sol");
var my1155Contract =artifacts.require("./My1155Contract.sol")
module.exports = function(deployer) {
  deployer.deploy(NFTAuction);
  deployer.deploy(my1155Contract,"http://ipfs.zifu.vip/ipns/k51qzi5uqu5djhwoxgbo67x0iox7ts6b4mu0lixbu1oz1fxsm0e4bt8i45jazn/GameLootBox/1.png");
};
