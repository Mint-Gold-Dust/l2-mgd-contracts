// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MintGoldDustMemoir} from "mgd-v2-contracts/marketplace/MintGoldDustMemoir.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {TransparentUpgradeableProxy, TransparentProxyDeployer} from "./deploy_TransparentProxy.s.sol";

library MintGoldDustMemoirDeployer {
    function deployMintGoldDustMemoir(
        FileSystem fs,
        bool onlyImplementation
    ) internal returns (MintGoldDustMemoir) {
        string memory chainName = fs.getChainName(block.chainid);
        console.log("Deploying MintGoldDustMemoir...");

        MintGoldDustMemoir instance = new MintGoldDustMemoir();

        console.log("MintGoldDustMemoir implementation:", address(instance));

        if (onlyImplementation) {
            return instance;
        } else {
            ProxyAdmin proxyAdmin;
            try fs.getAddress("ProxyAdmin", chainName) returns (address addr) {
                proxyAdmin = ProxyAdmin(addr);
            } catch {
                proxyAdmin = ProxyAdminDeployer.deployProxyAdmin(fs);
            }

            bytes memory initData = "";
            address proxy = TransparentProxyDeployer.deployTransparentProxy(
                fs,
                address(proxyAdmin),
                address(instance),
                initData,
                "MintGoldDustMemoir"
            );
            console.log("Saved MintGoldDustMemoir filesystem:", proxy);
            return MintGoldDustMemoir(proxy);
        }
    }
}
