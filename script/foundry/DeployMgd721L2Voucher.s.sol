// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/marketplace/MintGoldDustCompany.sol";
import {Mgd721L2Voucher} from "../../src/voucher/Mgd721L2Voucher.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract DeployMgd721L2Voucher is Script {
  /// Initialize params
  address private _OWNER;
  address private constant PROXY_ADMIN_L2 = 0x5D69C4aC749C9e76f15f566c227FcC1f9DF1592a;
  address private constant COMPANY_L2 = 0x54B89630089E9fE3f5138b38a2f84Bb9Ce4F2978;
  address private constant ESCROW_L1 = 0x77851abBE586ef590FC5024b0ca30E7875d077bE;
  address private constant NFT721_L1 = 0x34919B12852806Ca34B7746A75351cF89965A306;

  address private constant L2_CROSSDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public proxy;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/DeployMgd721L2Voucher.s.sol
   */
  function run() public {
    proxyAdmin = PROXY_ADMIN_L2;
    vm.startBroadcast();

    _OWNER = msg.sender;

    implementation = address(new Mgd721L2Voucher());
    console.log("Deployed implementation {Mgd721L2Voucher}:", implementation);

    console.log("proxyAdmin {ProxyAdmin}:", proxyAdmin);

    bytes memory data = abi.encodeWithSelector(
      Mgd721L2Voucher.initialize.selector,
      COMPANY_L2,
      ESCROW_L1,
      NFT721_L1,
      L2_CROSSDOMAIN_MESSENGER
    );
    bytes memory contructorArgs = abi.encode(implementation, proxyAdmin, data);
    console.log("TransparentUpgradeableProxy constructor arguments:");
    console.logBytes(contructorArgs);

    proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    console.log("TransparentUpgradeableProxy for {Mgd721L2Voucher} deployed:", proxy);

    vm.stopBroadcast();
  }
}
