// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MintGoldDustSetPrice} from "mgd-v2-contracts/marketplace/MintGoldDustSetPrice.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {
  TransparentUpgradeableProxy, TransparentProxyDeployer
} from "./deploy_TransparentProxy.s.sol";

struct MintGoldDustSetPriceParams {
  address mintGoldDustCompany;
  address payable mintGoldDustERC721Address;
  address payable mintGoldDustERC1155Address;
}

library MintGoldDustSetPriceDeployer {
  function deployMintGoldDustSetPrice(
    FileSystem fs,
    MintGoldDustSetPriceParams memory initParams,
    bool onlyImplementation
  )
    internal
    returns (MintGoldDustSetPrice)
  {
    string memory chainName = fs.getChainName(block.chainid);
    console.log("Deploying MintGoldDustSetPrice...");

    MintGoldDustSetPrice instance = new MintGoldDustSetPrice();

    console.log("MintGoldDustSetPrice implementation:", address(instance));

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
        MintGoldDustSetPrice.initializeChild.selector,
        initParams.mintGoldDustCompany,
        initParams.mintGoldDustERC721Address,
        initParams.mintGoldDustERC1155Address
      );

      address proxy = TransparentProxyDeployer.deployTransparentProxy(
        fs, address(proxyAdmin), address(instance), initData, "MintGoldDustSetPrice"
      );
      console.log("Saved MintGoldDustSetPrice filesystem:", proxy);
      return MintGoldDustSetPrice(proxy);
    }
  }
}
