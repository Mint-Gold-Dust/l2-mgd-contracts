// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/marketplace/MintGoldDustCompany.sol";
import {MgdL2NFTEscrow} from "../../src/MgdL2NFTEscrow.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract DeployMgdL2NFTEscrow is Script {
  /// Initialize params
  address private _OWNER;

  address private constant PROXY_ADMIN_L1 = 0x6D9755a1967Db29221A36D0f3F7b67dD447e2e36;
  address private constant COMPANY_L1 = 0xBA2a693d70D68667Cd346D69Da6F9D633C16f467;
  address private constant L1_CROSSDOMAIN_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public proxy;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/DeployMgdL2NFTEscrow.s.sol
   */
  function run() public {
    proxyAdmin = PROXY_ADMIN_L1;
    vm.startBroadcast();

    _OWNER = msg.sender;
    implementation = address(new MgdL2NFTEscrow());
    console.log("Deployed implementation {MgdL2NFTEscrow}:", implementation);

    console.log("ProxyAdmin {ProxyAdmin}:", proxyAdmin);

    bytes memory data = abi.encodeWithSelector(MgdL2NFTEscrow.initialize.selector, COMPANY_L1);
    proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    bytes memory contructorArgs = abi.encode(implementation, proxyAdmin, data);
    console.log("TransparentUpgradeableProxy constructor arguments:");
    console.logBytes(contructorArgs);

    proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    console.log("TransparentUpgradeableProxy for {MgdL2NFTEscrow} deployed:", proxy);

    vm.stopBroadcast();
  }
}
