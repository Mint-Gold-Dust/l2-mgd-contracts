// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {Mgd1155L2Voucher} from "../../../src/voucher/Mgd1155L2Voucher.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {TransparentUpgradeableProxy, TransparentProxyDeployer} from "./deploy_TransparentProxy.s.sol";

struct Mgd1155L2VoucherParams {
    address mgdCompanyL2Sync;
    address mgdL2NFTescrow;
    address mgdERC1155;
    address crossDomainMessenger;
}

library Mgd1155L2VoucherDeployer {
    function deployMgd1155L2Voucher(
        FileSystem fs,
        Mgd1155L2VoucherParams memory initParams,
        bool onlyImplementation
    ) internal returns (Mgd1155L2Voucher) {
        string memory chainName = fs.getChainName(block.chainid);
        console.log("Deploying Mgd1155L2Voucher...");

        Mgd1155L2Voucher instance = new Mgd1155L2Voucher();

        console.log("Mgd1155L2Voucher implementation:", address(instance));

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
                Mgd1155L2Voucher.initialize.selector,
                initParams.mgdCompanyL2Sync,
                initParams.mgdL2NFTescrow,
                initParams.mgdERC1155,
                initParams.crossDomainMessenger
            );

            address proxy = TransparentProxyDeployer.deployTransparentProxy(
                fs,
                address(proxyAdmin),
                address(instance),
                initData,
                "Mgd1155L2Voucher"
            );
            console.log("Saved Mgd1155L2Voucher filesystem:", proxy);
            return Mgd1155L2Voucher(proxy);
        }
    }
}
