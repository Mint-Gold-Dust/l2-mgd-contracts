// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "./utils/FileSystem.s.sol";
import {MgdCompanyL2SyncDeployer, MgdCompanyL2SyncParams} from "./deploy/deploy_MgdCompanyL2Sync.s.sol";

/**
 * @dev Run using shell command:
 * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
 * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/GlobalDeployerScript.s.sol
 */
contract GlobalDeployerScript is FileSystem {
    FileSystem fs;

    function run() public {
        fs = new FileSystem();

        MgdCompanyL2SyncParams memory initParams = MgdCompanyL2SyncParams({
            owner: msg.sender,
            primarySaleFeePercent: 10,
            secondarySaleFeePercent: 10,
            collectorFee: 10,
            maxRoyalty: 10,
            auctionDurationInMinutes: 10,
            auctionFinalMinute: 10
        });

        vm.startBroadcast();
        MgdCompanyL2SyncDeployer.deployMgdCompanyL2Sync(fs, initParams, false);
        vm.stopBroadcast();
    }
}
