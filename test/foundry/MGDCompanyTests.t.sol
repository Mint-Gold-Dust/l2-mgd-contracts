// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/StdUtils.sol";

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MgdCompanyL2Sync, CrossAction} from "../../src/MgdCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";
import {MockCrossDomainMessenger as CDMessenger} from "../mocks/MockCrossDomainMessenger.sol";

contract MGDCompanyTests is Test {
  // OP stack test constants
  address private constant L1_CROSSDOMAIN_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa; //mainnet
  address private constant L2_CROSSDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007; // base

  /// Initialize test params
  address private _OWNER;
  uint256 private constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 private constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 private constant _COLLECTOR_FEE = 3e18;
  uint256 private constant _MAX_ROYALTY = 20e18;
  uint256 private constant _AUCTION_DURATION = 1 days;
  uint256 private constant _AUCTION_EXTENSION = 5 minutes;

  uint256 private constant _TEST_CHAIN_ID = 31337;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public l1Proxy;
  address public l2Proxy;

  VmSafe.Wallet public Alice;
  VmSafe.Wallet public Bob;
  VmSafe.Wallet public Charlie;
  VmSafe.Wallet public MGDSigner;

  // events
  event SentMessage(
    address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit
  );

  function setUp() public {
    Alice = vm.createWallet("Alice");
    Bob = vm.createWallet("Bob");
    Charlie = vm.createWallet("Charlie");
    MGDSigner = vm.createWallet("MgdSigner");

    _OWNER = Alice.addr;

    vm.startPrank(Alice.addr);
    implementation = address(new MgdCompanyL2Sync());
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

    l1Proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    l2Proxy = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));

    MgdCompanyL2Sync(l1Proxy).setPublicKey(MGDSigner.addr);
    MgdCompanyL2Sync(l2Proxy).setPublicKey(MGDSigner.addr);

    MgdCompanyL2Sync(l1Proxy).setValidator(Bob.addr, true);
    MgdCompanyL2Sync(l2Proxy).setValidator(Bob.addr, true);

    MgdCompanyL2Sync(l1Proxy).setCrossDomainMessenger(L1_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l1Proxy).setCrossDomainMGDCompany(_TEST_CHAIN_ID, l2Proxy); // localhost

    MgdCompanyL2Sync(l2Proxy).setCrossDomainMessenger(L2_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l2Proxy).setCrossDomainMGDCompany(_TEST_CHAIN_ID, l1Proxy); // localhost

    deployCodeTo("MockCrossDomainMessenger.sol", L1_CROSSDOMAIN_MESSENGER);

    deployCodeTo("MockCrossDomainMessenger.sol", L2_CROSSDOMAIN_MESSENGER);

    vm.stopPrank();
  }

  function test_sendMessage() public {
    bytes memory message = abi.encode("Hello World!");
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l1Proxy, Alice.addr, message, nonce, 1_000_000);
    vm.prank(Alice.addr);
    CDMessenger(L1_CROSSDOMAIN_MESSENGER).sendMessage(l1Proxy, message, 1_000_000);
  }

  function test_calledByNoOwnerOrValidator(address foe) public {
    vm.assume(foe != Bob.addr && foe != Alice.addr && foe != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_signature(
      CrossAction.SetWhitelist, Charlie.addr, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );

    vm.expectRevert(MintGoldDustCompany.Unauthorized.selector);
    vm.prank(foe);
    MgdCompanyL2Sync(l1Proxy).whitelistWithL2Sync(
      Charlie.addr, true, _TEST_CHAIN_ID, deadline, signature
    );

    vm.expectRevert("Ownable: caller is not the owner");
    vm.prank(foe);
    MgdCompanyL2Sync(l1Proxy).setValidatorWithL2Sync(
      Charlie.addr, true, _TEST_CHAIN_ID, deadline, signature
    );
  }

  function test_whitelist(address artist) public {
    vm.assume(artist != Bob.addr && artist != Alice.addr && artist != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_signature(
      CrossAction.SetWhitelist, artist, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );
    bytes memory sentCalldata =
      abi.encode(CrossAction.SetWhitelist, artist, true, deadline, signature);

    bytes memory message =
      abi.encodeWithSelector(MgdCompanyL2Sync.receiveL1Sync.selector, sentCalldata);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l2Proxy, l1Proxy, message, nonce, 1_000_000);
    vm.prank(Bob.addr);
    MgdCompanyL2Sync(l1Proxy).whitelistWithL2Sync(artist, true, _TEST_CHAIN_ID, deadline, signature);

    assertEq(MgdCompanyL2Sync(l1Proxy).isArtistApproved(artist), true);

    _receiveCrossAction(sentCalldata);

    assertEq(MgdCompanyL2Sync(l2Proxy).isArtistApproved(artist), true);
  }

  function test_setValidator(address validator) public {
    vm.assume(validator != Bob.addr && validator != Alice.addr && validator != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_signature(
      CrossAction.SetValidator, validator, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );

    bytes memory sentCalldata =
      abi.encode(CrossAction.SetValidator, validator, true, deadline, signature);

    bytes memory message =
      abi.encodeWithSelector(MgdCompanyL2Sync.receiveL1Sync.selector, sentCalldata);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l2Proxy, l1Proxy, message, nonce, 1_000_000);
    vm.prank(Alice.addr);
    MgdCompanyL2Sync(l1Proxy).setValidatorWithL2Sync(
      validator, true, _TEST_CHAIN_ID, deadline, signature
    );

    assertEq(MgdCompanyL2Sync(l1Proxy).isAddressValidator(validator), true);
    _receiveCrossAction(sentCalldata);
    assertEq(MgdCompanyL2Sync(l2Proxy).isAddressValidator(validator), true);
  }

  function _receiveCrossAction(bytes memory data) public {
    vm.startPrank(L2_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l2Proxy).receiveL1Sync(data);
  }

  function generate_signature(
    CrossAction action,
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline,
    uint256 signerPrivKey
  )
    private
    view
    returns (bytes memory signature)
  {
    bytes32 digest =
      MgdCompanyL2Sync(l1Proxy).getDigestToSign(action, account, state, chainId, deadline);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivKey, digest);
    return abi.encodePacked(r, s, v);
  }
}
