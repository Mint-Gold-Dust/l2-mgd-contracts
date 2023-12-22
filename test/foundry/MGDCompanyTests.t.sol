// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants, CDMessenger} from "./op-stack/BaseL2Constants.t.sol";
import {MgdTestConstants} from "./utils/MgdTestConstants.t.sol";
import {Helpers} from "./utils/Helpers.t.sol";

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MgdCompanyL2Sync, CrossAction} from "../../src/MgdCompanyL2Sync.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

contract MGDCompanyTests is CommonSigners, BaseL2Constants, MgdTestConstants, Helpers {
  /// Initialize test params
  address private _OWNER;

  /// addresses
  address public implementation;
  address public proxyAdmin;
  address public l1mgdCompany;
  address public l2mgdCompany;

  function setUp() public {
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

    l1mgdCompany = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    l2mgdCompany = address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));

    MgdCompanyL2Sync(l1mgdCompany).setPublicKey(MGDSigner.addr);
    MgdCompanyL2Sync(l2mgdCompany).setPublicKey(MGDSigner.addr);

    MgdCompanyL2Sync(l1mgdCompany).setValidator(Bob.addr, true);
    MgdCompanyL2Sync(l2mgdCompany).setValidator(Bob.addr, true);

    MgdCompanyL2Sync(l1mgdCompany).setMessenger(L1_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l1mgdCompany).setCrossDomainMGDCompany(_TEST_CHAIN_ID, l2mgdCompany); // localhost

    MgdCompanyL2Sync(l2mgdCompany).setMessenger(L2_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l2mgdCompany).setCrossDomainMGDCompany(_TEST_CHAIN_ID, l1mgdCompany); // localhost
    vm.stopPrank();
  }

  function test_sendMessage() public {
    bytes memory message = abi.encode("Hello World!");
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l1mgdCompany, Alice.addr, message, nonce, 1_000_000);
    vm.prank(Alice.addr);
    CDMessenger(L1_CROSSDOMAIN_MESSENGER).sendMessage(l1mgdCompany, message, 1_000_000);
  }

  function test_calledByNoOwnerOrValidator(address foe) public {
    vm.assume(foe != Bob.addr && foe != Alice.addr && foe != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_actionSignature(
      CrossAction.SetWhitelist, Charlie.addr, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );

    vm.expectRevert(MintGoldDustCompany.Unauthorized.selector);
    vm.prank(foe);
    MgdCompanyL2Sync(l1mgdCompany).whitelistWithL2Sync(
      Charlie.addr, true, _TEST_CHAIN_ID, deadline, signature
    );

    vm.expectRevert("Ownable: caller is not the owner");
    vm.prank(foe);
    MgdCompanyL2Sync(l1mgdCompany).setValidatorWithL2Sync(
      Charlie.addr, true, _TEST_CHAIN_ID, deadline, signature
    );
  }

  function test_whitelist(address artist) public {
    vm.assume(artist != Bob.addr && artist != Alice.addr && artist != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_actionSignature(
      CrossAction.SetWhitelist, artist, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );
    bytes memory sentCalldata =
      abi.encode(CrossAction.SetWhitelist, artist, true, deadline, signature);

    bytes memory message =
      abi.encodeWithSelector(MgdCompanyL2Sync.receiveL1Sync.selector, sentCalldata);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l2mgdCompany, l1mgdCompany, message, nonce, 1_000_000);
    vm.prank(Bob.addr);
    MgdCompanyL2Sync(l1mgdCompany).whitelistWithL2Sync(
      artist, true, _TEST_CHAIN_ID, deadline, signature
    );

    assertEq(MgdCompanyL2Sync(l1mgdCompany).isArtistApproved(artist), true);

    _receiveCrossAction(sentCalldata);

    assertEq(MgdCompanyL2Sync(l2mgdCompany).isArtistApproved(artist), true);
  }

  function test_setValidator(address validator) public {
    vm.assume(validator != Bob.addr && validator != Alice.addr && validator != address(0));

    uint256 deadline = block.timestamp + 1 days;
    bytes memory signature = generate_actionSignature(
      CrossAction.SetValidator, validator, true, _TEST_CHAIN_ID, deadline, MGDSigner.privateKey
    );

    bytes memory sentCalldata =
      abi.encode(CrossAction.SetValidator, validator, true, deadline, signature);

    bytes memory message =
      abi.encodeWithSelector(MgdCompanyL2Sync.receiveL1Sync.selector, sentCalldata);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();
    vm.expectEmit(true, false, false, true);
    emit SentMessage(l2mgdCompany, l1mgdCompany, message, nonce, 1_000_000);
    vm.prank(Alice.addr);
    MgdCompanyL2Sync(l1mgdCompany).setValidatorWithL2Sync(
      validator, true, _TEST_CHAIN_ID, deadline, signature
    );

    assertEq(MgdCompanyL2Sync(l1mgdCompany).isAddressValidator(validator), true);
    _receiveCrossAction(sentCalldata);
    assertEq(MgdCompanyL2Sync(l2mgdCompany).isAddressValidator(validator), true);
  }

  function _receiveCrossAction(bytes memory data) public {
    vm.startPrank(L2_CROSSDOMAIN_MESSENGER);
    MgdCompanyL2Sync(l2mgdCompany).receiveL1Sync(data);
  }

  function generate_actionSignature(
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
      MgdCompanyL2Sync(l1mgdCompany).getDigestToSign(action, account, state, chainId, deadline);
    return generate_packedSignature(digest, signerPrivKey);
  }
}
