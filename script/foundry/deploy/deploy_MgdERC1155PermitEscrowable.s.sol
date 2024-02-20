// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {
  MgdERC1155PermitEscrowable,
  MintGoldDustERC1155
} from "../../../src/MgdERC1155PermitEscrowable.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {
  TransparentUpgradeableProxy, TransparentProxyDeployer
} from "./deploy_TransparentProxy.s.sol";

struct MgdERC1155PermitEscrowableParams {
  address mgdCompanyL2Sync;
  string baseURI;
}

library MgdERC1155PermitEscrowableDeployer {
  function deployMgdERC1155PermitEscrowable(
    FileSystem fs,
    MgdERC1155PermitEscrowableParams memory initParams,
    bool onlyImplementation
  )
    internal
    returns (MgdERC1155PermitEscrowable)
  {
    string memory chainName = fs.getChainName(block.chainid);
    console.log("Deploying MgdERC1155PermitEscrowable...");

    MgdERC1155PermitEscrowable instance = new MgdERC1155PermitEscrowable();

    console.log("MgdERC1155PermitEscrowable implementation:", address(instance));

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
        MintGoldDustERC1155.initializeChild.selector,
        initParams.mgdCompanyL2Sync,
        initParams.baseURI
      );

      address proxy = TransparentProxyDeployer.deployTransparentProxy(
        fs, address(proxyAdmin), address(instance), initData, "MgdERC1155PermitEscrowable"
      );
      console.log("Saved MgdERC1155PermitEscrowable filesystem:", proxy);
      return MgdERC1155PermitEscrowable(proxy);
    }
  }
}
