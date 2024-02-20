// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MintGoldDustMarketplaceAuction} from
  "mgd-v2-contracts/marketplace/MintGoldDustMarketplaceAuction.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {
  TransparentUpgradeableProxy, TransparentProxyDeployer
} from "./deploy_TransparentProxy.s.sol";

struct MintGoldDustMarketplaceAuctionParams {
  address mintGoldDustCompany;
  address payable mintGoldDustERC721Address;
  address payable mintGoldDustERC1155Address;
}

library MintGoldDustMarketplaceAuctionDeployer {
  function deployMintGoldDustMarketplaceAuction(
    FileSystem fs,
    MintGoldDustMarketplaceAuctionParams memory initParams,
    bool onlyImplementation
  )
    internal
    returns (MintGoldDustMarketplaceAuction)
  {
    string memory chainName = fs.getChainName(block.chainid);
    console.log("Deploying MintGoldDustMarketplaceAuction...");

    MintGoldDustMarketplaceAuction instance = new MintGoldDustMarketplaceAuction();

    console.log("MintGoldDustMarketplaceAuction implementation:", address(instance));

    if (onlyImplementation) {
      return instance;
    } else {
      ProxyAdmin proxyAdmin;
      try fs.getAddress("ProxyAdmin", chainName) returns (address addr) {
        proxyAdmin = ProxyAdmin(addr);
      } catch {
        proxyAdmin = ProxyAdminDeployer.deployProxyAdmin(fs);
      }

      bytes memory initData = abi.encodeWithSelector(
        MintGoldDustMarketplaceAuction.initializeChild.selector,
        initParams.mintGoldDustCompany,
        initParams.mintGoldDustERC721Address,
        initParams.mintGoldDustERC1155Address
      );

      address proxy = TransparentProxyDeployer.deployTransparentProxy(
        fs, address(proxyAdmin), address(instance), initData, "MintGoldDustMarketplaceAuction"
      );
      console.log("Saved MintGoldDustMarketplaceAuction filesystem:", proxy);
      return MintGoldDustMarketplaceAuction(proxy);
    }
  }
}
