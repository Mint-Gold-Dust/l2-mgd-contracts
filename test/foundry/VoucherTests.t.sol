// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants, CDMessenger} from "./op-stack/BaseL2Constants.t.sol";
import {MgdTestConstants} from "./utils/MgdTestConstants.t.sol";

import {
  MgdERC1155PermitEscrowable as Mgd1155PE,
  MintGoldDustERC1155
} from "../../src/MgdERC1155PermitEscrowable.sol";
import {
  MgdERC721PermitEscrowable as Mgd721PE,
  MintGoldDustERC721
} from "../../src/MgdERC721PermitEscrowable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
  "../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";
import {MgdCompanyL2Sync, MintGoldDustCompany} from "../../src/MgdCompanyL2Sync.sol";
import {MgdL1MarketData, TypeNFT} from "../../src/voucher/VoucherDataTypes.sol";
import {MgdL2NFTEscrow} from "../../src/MgdL2NFTEscrow.sol";
import {MgdL2BaseNFT} from "../../src/voucher/MgdL2BaseNFT.sol";
import {Mgd721L2Voucher} from "../../src/voucher/Mgd721L2Voucher.sol";
import {Mgd1155L2Voucher} from "../../src/voucher/Mgd1155L2Voucher.sol";

contract VoucherTests is CommonSigners, BaseL2Constants, MgdTestConstants {
  /// addresses
  address public proxyAdmin;

  Mgd721PE public nft721;
  Mgd1155PE public nft1155;
  MgdL2NFTEscrow public escrow;

  Mgd721L2Voucher public l2voucher721;
  Mgd1155L2Voucher public l2voucher1155;

  MgdCompanyL2Sync public company;
  address public companyOwner;

  /// Local constants: mock data to mint NFTs
  string private constant _TOKEN_URI = "https://ipfs.nowhere.example/";
  uint256 private constant _ROYALTY_PERCENT = 10;
  string private constant _MEMOIR = "A memoir";
  uint40 private constant _EDITIONS = 10;

  uint256[] private _721tokenIdsOfBob;

  /// Test Vouchers
  uint256 nativeVoucherIdFor721;
  uint256 nativeVoucherIdFor1155;
  uint256 nativeSplitVoucherId;

  function setUp() public {
    companyOwner = Alice.addr;
    vm.startPrank(companyOwner);
    proxyAdmin = address(new ProxyAdmin());

    // 1.- Deploying company
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
    // 1.1- Set messenger in company
    MgdCompanyL2Sync(company).setMessenger(L1_CROSSDOMAIN_MESSENGER);

    // 2.- Deploying NFT Contracts
    bytes memory nftInitData;
    // 2.1- ERC721
    nftInitData =
      abi.encodeWithSelector(MintGoldDustERC721.initializeChild.selector, address(company));
    address nft721Impl = address(new Mgd721PE());
    nft721 = Mgd721PE(address(new TransparentUpgradeableProxy(nft721Impl, proxyAdmin, nftInitData)));

    // 2.2- ERC1155
    nftInitData = abi.encodeWithSelector(
      MintGoldDustERC1155.initializeChild.selector, address(company), _TOKEN_URI
    );
    address nft1155Impl = address(new Mgd1155PE());
    nft1155 =
      Mgd1155PE(address(new TransparentUpgradeableProxy(nft1155Impl, proxyAdmin, nftInitData)));

    // 3.- Deploying Escrow
    address escrowImpl = address(new MgdL2NFTEscrow());
    bytes memory escrowInitData =
      abi.encodeWithSelector(MgdL2NFTEscrow.initialize.selector, address(company));
    escrow = MgdL2NFTEscrow(
      address(new TransparentUpgradeableProxy(escrowImpl, proxyAdmin, escrowInitData))
    );

    // 4.- Deploying L2 Vouchers (pretending vouchers are on a different chain to simplify tests)
    bytes memory l2voucherInitData;
    // 4.1- 721 Voucher
    address l2voucher721Impl = address(new Mgd721L2Voucher());
    l2voucherInitData = abi.encodeWithSelector(
      Mgd721L2Voucher.initialize.selector,
      address(company),
      address(escrow),
      address(nft721),
      L2_CROSSDOMAIN_MESSENGER
    );
    l2voucher721 = Mgd721L2Voucher(
      address(new TransparentUpgradeableProxy(l2voucher721Impl, proxyAdmin, l2voucherInitData))
    );
    // 4.2- 1155 Voucher
    address l2voucher1155Impl = address(new Mgd1155L2Voucher());
    l2voucherInitData = abi.encodeWithSelector(
      Mgd1155L2Voucher.initialize.selector,
      address(company),
      address(escrow),
      address(nft1155),
      L2_CROSSDOMAIN_MESSENGER
    );
    l2voucher1155 = Mgd1155L2Voucher(
      address(new TransparentUpgradeableProxy(l2voucher1155Impl, proxyAdmin, l2voucherInitData))
    );

    // 5.- Set Escrow in NFTs
    nft721.setEscrow(address(escrow));
    nft1155.setEscrow(address(escrow));

    // 6.- Set l2 voucher address in escrow
    escrow.setVoucherL2(address(l2voucher721), TypeNFT.ERC721);
    escrow.setVoucherL2(address(l2voucher1155), TypeNFT.ERC1155);

    // 7.- Whitelist Bob as artist
    company.whitelist(Bob.addr, true);

    vm.stopPrank();

    // 8.- Bob Mints an NFT on ethereum
    vm.startPrank(Bob.addr);
    _721tokenIdsOfBob.push(nft721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR)));
    vm.stopPrank();
  }

  function test_mintingNativeVoucherThatRepresents721() public {
    vm.prank(Bob.addr);
    uint256 vId = l2voucher721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR));
    nativeVoucherIdFor721 = vId;
    assertEq(l2voucher721.ownerOf(vId), Bob.addr);
  }

  function test_mintingNativeVoucherThatRepresents1155() public {
    vm.prank(Bob.addr);
    uint256 vId = l2voucher1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _EDITIONS, bytes(_MEMOIR));
    nativeVoucherIdFor1155 = vId;
    assertEq(l2voucher1155.balanceOf(Bob.addr, vId), _EDITIONS);
  }

  function test_mintingNativeSplitMinted721Voucher() public {
    address[] memory collabs = new address[](2);
    collabs[0] = Charlie.addr;
    collabs[1] = David.addr;

    uint256[] memory collabsPercent = new uint256[](3);
    collabsPercent[0] = 35e18;
    collabsPercent[1] = 20e18;
    collabsPercent[2] = 45e18;

    vm.prank(Bob.addr);
    uint256 vId = l2voucher721.splitMint(
      _TOKEN_URI, uint128(_ROYALTY_PERCENT), collabs, collabsPercent, 1, bytes(_MEMOIR)
    );
    nativeSplitVoucherId = vId;
    assertEq(l2voucher721.ownerOf(vId), Bob.addr);
  }

  function test_mintNativeSplitMinted1155Voucher() public {
    address[] memory collabs = new address[](2);
    collabs[0] = Charlie.addr;
    collabs[1] = David.addr;

    uint256[] memory collabsPercent = new uint256[](3);
    collabsPercent[0] = 35e18;
    collabsPercent[1] = 20e18;
    collabsPercent[2] = 45e18;

    vm.prank(Bob.addr);
    uint256 vId = l2voucher1155.splitMint(
      _TOKEN_URI, uint128(_ROYALTY_PERCENT), collabs, collabsPercent, _EDITIONS, bytes(_MEMOIR)
    );
    nativeSplitVoucherId = vId;
    assertEq(l2voucher1155.balanceOf(Bob.addr, vId), _EDITIONS);
  }

  function test_collectorMintingMethodsReverts() public {
    // l2voucher.collectorMint
    vm.prank(Bob.addr);
    vm.expectRevert(MgdL2BaseNFT.MgdL2Voucher__collectorMint_disabledInL2.selector);
    l2voucher721.collectorMint(
      _TOKEN_URI, _ROYALTY_PERCENT, 1, Bob.addr, bytes(_MEMOIR), 1234, address(this)
    );

    vm.prank(Bob.addr);
    vm.expectRevert(MgdL2BaseNFT.MgdL2Voucher__collectorMint_disabledInL2.selector);
    l2voucher1155.collectorMint(
      _TOKEN_URI, _ROYALTY_PERCENT, 1, Bob.addr, bytes(_MEMOIR), 1234, address(this)
    );

    // l2voucher.collectorSplitMint
    address[] memory collabs = new address[](2);
    collabs[0] = Charlie.addr;
    collabs[1] = David.addr;

    uint256[] memory collabsPercent = new uint256[](3);
    collabsPercent[0] = 35e18;
    collabsPercent[1] = 20e18;
    collabsPercent[2] = 45e18;

    vm.prank(Bob.addr);
    vm.expectRevert(MgdL2BaseNFT.MgdL2Voucher__collectorMint_disabledInL2.selector);
    l2voucher1155.collectorSplitMint(
      _TOKEN_URI,
      _ROYALTY_PERCENT,
      collabs,
      collabsPercent,
      1,
      Bob.addr,
      bytes(_MEMOIR),
      1234,
      address(this)
    );
  }
}
