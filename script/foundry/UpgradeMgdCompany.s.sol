// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MgdCompanyL2Sync} from "../../src/MgdCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract UpgradeMgdCompanyL2Sync is Script {
  /// Initialize params
  address private constant PROXY_ADMIN = 0x29FAd1fb39Ebd5090b12c3949462A64861DE7C6D;
  address private constant PROXY = 0xa0e656f94bB38c6941DF92a5F950Dc8A67bb5940;

  /// addresses
  address public newImplementation;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/UpgradeMgdCompanyL2Sync
   */
  function run() public {
    vm.startBroadcast();

    newImplementation = address(new MgdCompanyL2Sync());
    console.log("Deployed new implementation {MGDCompanyL2sync}:", newImplementation);

    // newImplementation = 0xD5E2fd38888ba0E2BdD20BB14B45EA3cBD3cA0e5; // original

    ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(PROXY), newImplementation);
    console.log("Succesfully upgraded MgdCompanyL2Sync proxy", PROXY);

    vm.stopBroadcast();
  }
}
