// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {Mgd721L2Voucher} from "../../../src/voucher/Mgd721L2Voucher.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {
  TransparentUpgradeableProxy, TransparentProxyDeployer
} from "./deploy_TransparentProxy.s.sol";

struct Mgd721L2VoucherParams {
  address mgdCompanyL2Sync;
  address mgdL2NFTescrow;
  address mgdERC721;
  address crossDomainMessenger;
}

library Mgd721L2VoucherDeployer {
  function deployMgd721L2Voucher(
    FileSystem fs,
    Mgd721L2VoucherParams memory initParams,
    bool onlyImplementation
  )
    internal
    returns (Mgd721L2Voucher)
  {
    string memory chainName = fs.getChainName(block.chainid);
    console.log("Deploying Mgd721L2Voucher...");

    Mgd721L2Voucher instance = new Mgd721L2Voucher();

    console.log("Mgd721L2Voucher implementation:", address(instance));

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
        Mgd721L2Voucher.initialize.selector,
        initParams.mgdCompanyL2Sync,
        initParams.mgdL2NFTescrow,
        initParams.mgdERC721,
        initParams.crossDomainMessenger
      );

      address proxy = TransparentProxyDeployer.deployTransparentProxy(
        fs, address(proxyAdmin), address(instance), initData, "Mgd721L2Voucher"
      );
      console.log("Saved Mgd721L2Voucher filesystem:", proxy);
      return Mgd721L2Voucher(proxy);
    }
  }
}
