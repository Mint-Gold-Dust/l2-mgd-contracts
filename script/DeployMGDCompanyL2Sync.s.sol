// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MGDCompanyL2Sync} from "../src/MGDCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract DeployMGDCompanyL2Sync is Script {
  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public proxy;

  address public pubkey;

  /// Initialize params
  address private _OWNER;
  uint256 private constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 private constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 private constant _COLLECTOR_FEE = 3e18;
  uint256 private constant _MAX_ROYALTY = 20e18;
  uint256 private constant _AUCTION_DURATION = 1 days;
  uint256 private constant _AUCTION_EXTENSION = 5 minutes;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast scripts/DeployMGDCompanyL2Sync
   */
  function run() public {
    vm.startBroadcast();

    _OWNER = msg.sender;

    implementation = address(new MGDCompanyL2Sync());
    console.log("Deployed implementation {MGDCompanyL2sync}:", implementation);

    proxyAdmin = address(new ProxyAdmin());

    bytes memory data = abi.encodeWithSelector(
      MintGoldDustCompany.initialize.selector,
      _OWNER,
      _PRIMARY_SALE_FEE_PERCENT,
      _SECONDARY_SALE_FEE_PERCENT,
      _COLLECTOR_FEE,
      _MAX_ROYALTY,
      _AUCTION_DURATION,
      _AUCTION_EXTENSION
    );
    bytes memory contructorArgs = abi.encode(implementation, proxyAdmin, data);
    console.log("TransparentUpgradeableProxy constructor arguments:");
    console.logBytes(contructorArgs);

    proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    console.log("Proxy for {MGDCompanyL2sync} deployed:", proxy);

    MGDCompanyL2Sync(proxy).setPublicKey(msg.sender);
    console.log("Called MGDCompanyL2Sync.setPublicKey()", msg.sender);

    vm.stopBroadcast();
  }
}