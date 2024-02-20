// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MgdL2NFTEscrow} from "../../../src/MgdL2NFTEscrow.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {
  TransparentUpgradeableProxy, TransparentProxyDeployer
} from "./deploy_TransparentProxy.s.sol";

struct MgdL2NFTEscrowParams {
  address mgdCompanyL2Sync;
}

library MgdL2NFTEscrowDeployer {
  function deployMgdL2NFTEscrow(
    FileSystem fs,
    MgdL2NFTEscrowParams memory initParams,
    bool onlyImplementation
  )
    internal
    returns (MgdL2NFTEscrow)
  {
    string memory chainName = fs.getChainName(block.chainid);
    console.log("Deploying MgdL2NFTEscrow...");

    MgdL2NFTEscrow instance = new MgdL2NFTEscrow();

    console.log("MgdL2NFTEscrow implementation:", address(instance));

    if (onlyImplementation) {
      return instance;
    } else {
      ProxyAdmin proxyAdmin;
      try fs.getAddress("ProxyAdmin", chainName) returns (address addr) {
        proxyAdmin = ProxyAdmin(addr);
      } catch {
        proxyAdmin = ProxyAdminDeployer.deployProxyAdmin(fs);
      }

      bytes memory initData =
        abi.encodeWithSelector(MgdL2NFTEscrow.initialize.selector, initParams.mgdCompanyL2Sync);

      address proxy = TransparentProxyDeployer.deployTransparentProxy(
        fs, address(proxyAdmin), address(instance), initData, "MgdL2NFTEscrow"
      );
      console.log("Saved MgdL2NFTEscrow filesystem:", proxy);
      return MgdL2NFTEscrow(proxy);
    }
  }
}
