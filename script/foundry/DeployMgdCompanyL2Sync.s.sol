// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MgdCompanyL2Sync} from "../../src/MgdCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract DeployMgdCompanyL2Sync is Script {
  /// Initialize params
  address private _OWNER;
  uint256 private constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 private constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 private constant _COLLECTOR_FEE = 3e18;
  uint256 private constant _MAX_ROYALTY = 20e18;
  uint256 private constant _AUCTION_DURATION = 1 days;
  uint256 private constant _AUCTION_EXTENSION = 5 minutes;

  address private constant L1_CROSSDOMAIN_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
  address private constant L2_CROSSDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public proxy;

  address public pubkey;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/DeployMgdCompanyL2Sync.s.sol
   */
  function run() public {
    vm.startBroadcast();

    _OWNER = msg.sender;

    implementation = address(new MgdCompanyL2Sync());
    console.log("Deployed implementation {MGDCompanyL2sync}:", implementation);

    proxyAdmin = address(new ProxyAdmin());
    console.log("Deployed proxyAdmin {ProxyAdmin}:", proxyAdmin);

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
    console.log("TransparentUpgradeableProxy for {MGDCompanyL2sync} deployed:", proxy);

    MgdCompanyL2Sync(proxy).setPublicKey(msg.sender);
    console.log("Called MgdCompanyL2Sync.setPublicKey()", msg.sender);

    // MgdCompanyL2Sync(proxy).setMessenger(L1_CROSSDOMAIN_MESSENGER);
    // console.log("Called MgdCompanyL2Sync.setMessenger()", L1_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(proxy).setMessenger(L2_CROSSDOMAIN_MESSENGER);
    console.log("Called MgdCompanyL2Sync.setMessenger()", L2_CROSSDOMAIN_MESSENGER);

    // MgdCompanyL2Sync(proxy).setCrossDomainMGDCompany(1, proxy); // mainnet
    // MgdCompanyL2Sync(proxy).setCrossDomainMGDCompany(8453, proxy); // base
    MgdCompanyL2Sync(proxy).setCrossDomainMGDCompany(11155111, proxy); // sepolia
    // MgdCompanyL2Sync(proxy).setCrossDomainMGDCompany(84532, proxy); // base-sepolia
    // MgdCompanyL2Sync(proxy).setCrossDomainMGDCompany(31337, proxy); // localhost
    console.log("Called MgdCompanyL2Sync.setCrossDomainMGDCompany()");

    vm.stopBroadcast();
  }
}
