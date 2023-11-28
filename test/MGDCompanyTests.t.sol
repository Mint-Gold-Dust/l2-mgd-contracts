// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/StdUtils.sol";

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MGDCompanyL2Sync} from "../src/MGDCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

// import {L1CrossDomainMessenger} from "../src/utils/L1/L1CrossDomainMessenger.sol";
// import {L2CrossDomainMessenger} from "optimism/contracts/L2/L2CrossDomainMessenger.sol";

contract MGDCompanyTests is Test {
  // OP stack test constants
  address private constant OPTIMISM_PORTAL = 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e; // mainnet
  address private constant L1CROSSDOMAIN_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa; //mainnet
  address private constant L2CROSSDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007; // base

  /// Initialize test params
  address private _OWNER;
  uint256 private constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 private constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 private constant _COLLECTOR_FEE = 3e18;
  uint256 private constant _MAX_ROYALTY = 20e18;
  uint256 private constant _AUCTION_DURATION = 1 days;
  uint256 private constant _AUCTION_EXTENSION = 5 minutes;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public proxy;

  VmSafe.Wallet public Alice;
  VmSafe.Wallet public Bob;
  VmSafe.Wallet public MGDSigner;

  function setUp() public {
    Alice = vm.createWallet("Alice's wallet");
    Bob = vm.createWallet("Bob's wallet");
    MGDSigner = vm.createWallet("MgdSigner's wallet");

    vm.startBroadcast(Alice.addr);
    _OWNER = Alice.addr;

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

    proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));

    MGDCompanyL2Sync(proxy).setPublicKey(MGDSigner.addr);
    MGDCompanyL2Sync(proxy).setCrossDomainMessenger(L1CROSSDOMAIN_MESSENGER);
    MGDCompanyL2Sync(proxy).setCrossDomainMGDCompany(31337, proxy); // localhost

    // vm.deployCodeTo(
    //   "lib/optimism/packages/contracts-bedrock/src/L1/L1CrossDomainMessenger.sol",
    //   L1CROSSDOMAIN_MESSENGER
    // );

    // vm.deployCodeTo(
    //   "lib/optimism/packages/contracts-bedrock/src/L2/L2CrossDomainMessenger.sol",
    //   L2CROSSDOMAIN_MESSENGER
    // );

    vm.stopBroadcast();
  }
}
