// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {MgdCompanyL2Sync, MintGoldDustCompany} from "../../../src/MgdCompanyL2Sync.sol";
import {ProxyAdmin, ProxyAdminDeployer} from "./deploy_ProxyAdmin.s.sol";
import {TransparentUpgradeableProxy, TransparentProxyDeployer} from "./deploy_TransparentProxy.s.sol";

struct MgdCompanyL2SyncParams {
    address owner;
    uint256 primarySaleFeePercent;
    uint256 secondarySaleFeePercent;
    uint256 collectorFee;
    uint256 maxRoyalty;
    uint256 auctionDurationInMinutes;
    uint256 auctionFinalMinute;
}

library MgdCompanyL2SyncDeployer {
    function deployMgdCompanyL2Sync(
        FileSystem fs,
        MgdCompanyL2SyncParams memory initParams,
        bool onlyImplementation
    ) internal returns (MgdCompanyL2Sync) {
        string memory chainName = fs.getChainName(block.chainid);
        console.log("Deploying MgdCompanyL2Sync...");

        MgdCompanyL2Sync instance = new MgdCompanyL2Sync();

        console.log("MgdCompanyL2Sync implementation:", address(instance));

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
                MintGoldDustCompany.initialize.selector,
                initParams.owner,
                initParams.primarySaleFeePercent,
                initParams.secondarySaleFeePercent,
                initParams.collectorFee,
                initParams.maxRoyalty,
                initParams.auctionDurationInMinutes,
                initParams.auctionFinalMinute
            );

            address proxy = TransparentProxyDeployer.deployTransparentProxy(
                fs,
                address(proxyAdmin),
                address(instance),
                initData,
                "MgdCompanyL2Sync"
            );
            console.log("Saved MgdCompanyL2Sync filesystem:", proxy);
            return MgdCompanyL2Sync(proxy);
        }
    }
}
