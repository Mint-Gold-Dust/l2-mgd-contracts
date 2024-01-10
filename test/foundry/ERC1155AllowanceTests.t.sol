// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants} from "./op-stack/BaseL2Constants.t.sol";
import {MgdTestConstants} from "./utils/MgdTestConstants.t.sol";
import {Helpers} from "./utils/Helpers.t.sol";

import {
  MgdERC1155PermitEscrowable as Mgd1155PE,
  MintGoldDustERC1155
} from "../../src/MgdERC1155PermitEscrowable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";
import {MgdCompanyL2Sync, MintGoldDustCompany} from "../../src/MgdCompanyL2Sync.sol";

contract ERC1155AllowanceTests is CommonSigners, BaseL2Constants, MgdTestConstants, Helpers {
  event ApprovalByAmount(
    address indexed owner, address indexed operator, uint256 indexed id, uint256 amount
  );

  /// addresses
  address public proxyAdmin;
  address public nftImpl;
  Mgd1155PE public nft;
  MgdCompanyL2Sync public company;

  address public companyOwner;

  /// Local constants
  string private constant _TOKEN_URI = "https://ipfs.nowhere.example/";
  uint256 private constant _ROYALTY_PERCENT = 10;
  uint256 private constant _DEFAULT_AMOUNT = 100;
  string private constant _MEMOIR = "A memoir";

  uint256[] private _tokenIdsOfBob;

  function setUp() public {
    companyOwner = Alice.addr;
    vm.startPrank(companyOwner);
    proxyAdmin = address(new ProxyAdmin());

    address companyImpl = address(new MgdCompanyL2Sync());
    bytes memory companyInitData = abi.encodeWithSelector(
      MintGoldDustCompany.initialize.selector,
      companyOwner,
      _PRIMARY_SALE_FEE_PERCENT,
      _SECONDARY_SALE_FEE_PERCENT,
      _COLLECTOR_FEE,
      _MAX_ROYALTY,
      _AUCTION_DURATION,
      _AUCTION_EXTENSION
    );
    company = MgdCompanyL2Sync(
      address(new TransparentUpgradeableProxy(companyImpl, proxyAdmin, companyInitData))
    );
    company.whitelist(Bob.addr, true);
    bytes memory nftInitData = abi.encodeWithSelector(
      MintGoldDustERC1155.initializeChild.selector, address(company), _TOKEN_URI
    );
    nftImpl = address(new Mgd1155PE());
    nft = Mgd1155PE(address(new TransparentUpgradeableProxy(nftImpl, proxyAdmin, nftInitData)));
    vm.stopPrank();

    vm.startPrank(Bob.addr);
    _tokenIdsOfBob.push(nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR)));
    _tokenIdsOfBob.push(nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR)));
    _tokenIdsOfBob.push(nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR)));
    vm.stopPrank();
  }

  function testFail_ApproveAllowanceZeroAddress() public {
    // Test setAllowance function with operator address zero
    vm.prank(Bob.addr);
    nft.approve(address(0), _tokenIdsOfBob[0], _DEFAULT_AMOUNT);
  }

  function testFail_ApproveAllowanceZeroTokenId() public {
    // Test setAllowance function with tokenId zero
    vm.prank(Bob.addr);
    nft.approve(Alice.addr, 0, _DEFAULT_AMOUNT);
  }

  function test_approveAllowance() public {
    // Test setAllowance function
    vm.startPrank(Bob.addr);
    nft.approve(Alice.addr, _tokenIdsOfBob[0], _DEFAULT_AMOUNT / 2);
    nft.approve(Alice.addr, _tokenIdsOfBob[1], _DEFAULT_AMOUNT);
    nft.approve(Alice.addr, _tokenIdsOfBob[2], _DEFAULT_AMOUNT / 5);
    vm.stopPrank();
    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[0]), _DEFAULT_AMOUNT / 2);
    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[1]), _DEFAULT_AMOUNT);
    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[2]), _DEFAULT_AMOUNT / 5);
  }

  function test_approveEmitsEvent() public {
    // Test setAllowance function
    vm.prank(Bob.addr);
    vm.expectEmit(true, true, false, true);
    emit ApprovalByAmount(Bob.addr, Alice.addr, _tokenIdsOfBob[0], _DEFAULT_AMOUNT / 2);
    nft.approve(Alice.addr, _tokenIdsOfBob[0], _DEFAULT_AMOUNT / 2);
  }

  function test_spendAllowanceProperly(uint8 spend1, uint8 spend2, uint8 spend3) public {
    uint256 spendable1 = bound(spend1, 1, _DEFAULT_AMOUNT);
    uint256 spendable2 = bound(spend2, 1, _DEFAULT_AMOUNT);
    uint256 spendable3 = bound(spend3, 1, _DEFAULT_AMOUNT);

    vm.startPrank(Bob.addr);
    nft.approve(Alice.addr, _tokenIdsOfBob[0], _DEFAULT_AMOUNT);
    nft.approve(Alice.addr, _tokenIdsOfBob[1], _DEFAULT_AMOUNT);
    nft.approve(Alice.addr, _tokenIdsOfBob[2], _DEFAULT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(Alice.addr);
    nft.safeTransferFrom(Bob.addr, Alice.addr, _tokenIdsOfBob[0], spendable1, "");
    nft.safeTransferFrom(Bob.addr, Alice.addr, _tokenIdsOfBob[1], spendable2, "");
    nft.safeTransferFrom(Bob.addr, Alice.addr, _tokenIdsOfBob[2], spendable3, "");
    vm.stopPrank();

    assertEq(nft.balanceOf(Bob.addr, _tokenIdsOfBob[0]), _DEFAULT_AMOUNT - spendable1);
    assertEq(nft.balanceOf(Bob.addr, _tokenIdsOfBob[1]), _DEFAULT_AMOUNT - spendable2);
    assertEq(nft.balanceOf(Bob.addr, _tokenIdsOfBob[2]), _DEFAULT_AMOUNT - spendable3);

    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[0]), _DEFAULT_AMOUNT - spendable1);
    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[1]), _DEFAULT_AMOUNT - spendable2);
    assertEq(nft.allowance(Bob.addr, Alice.addr, _tokenIdsOfBob[2]), _DEFAULT_AMOUNT - spendable3);
  }
}
