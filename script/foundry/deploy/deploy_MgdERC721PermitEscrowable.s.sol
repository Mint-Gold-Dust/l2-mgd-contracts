// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MgdERC721PermitEscrowable, MintGoldDustERC721} from "../../../src/MgdERC721PermitEscrowable.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {TransparentUpgradeableProxy, TransparentProxyDeployer} from "./deploy_TransparentProxy.s.sol";

struct MgdERC721PermitEscrowableParams {
    address mgdCompanyL2Sync;
}

library MgdERC721PermitEscrowableDeployer {
    function deployMgdERC721PermitEscrowable(
        FileSystem fs,
        MgdERC721PermitEscrowableParams memory initParams,
        bool onlyImplementation
    ) internal returns (MgdERC721PermitEscrowable) {
        string memory chainName = fs.getChainName(block.chainid);
        console.log("Deploying MgdERC721PermitEscrowable...");

        MgdERC721PermitEscrowable instance = new MgdERC721PermitEscrowable();

        console.log(
            "MgdERC721PermitEscrowable implementation:",
            address(instance)
        );

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
                MintGoldDustERC721.initializeChild.selector,
                initParams.mgdCompanyL2Sync
            );

            address proxy = TransparentProxyDeployer.deployTransparentProxy(
                fs,
                address(proxyAdmin),
                address(instance),
                initData,
                "MgdERC721PermitEscrowable"
            );
            console.log("Saved MgdERC721PermitEscrowable filesystem:", proxy);
            return MgdERC721PermitEscrowable(proxy);
        }
    }
}
