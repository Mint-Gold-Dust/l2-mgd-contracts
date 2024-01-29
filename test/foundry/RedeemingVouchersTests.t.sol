// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/StdUtils.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants, CDMessenger} from "./op-stack/BaseL2Constants.t.sol";
import {MgdTestConstants} from "./utils/MgdTestConstants.t.sol";
import {Helpers} from "./utils/Helpers.t.sol";

import {MockMgdMarketPlace} from "../mocks/MockMgdMarketPlace.sol";

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

contract RedeemingVoucherTests is CommonSigners, BaseL2Constants, MgdTestConstants, Helpers {
  event RedeemVoucher(
    uint256 indexed voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed releaseKey
  );

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
  uint40 private constant _EDITIONS = 5;

  // Ethereum nfts
  uint256 _721tokenId;
  uint256 _721VId;
  uint256 _1155tokenId;
  uint256 _1155VId;

  /// Test Vouchers
  uint256 nativeVoucherIdFor721;
  uint256 nativeVoucherIdFor1155;

  // Mocks
  MockMgdMarketPlace public mockMarketPlace;

  function setUp() public {
    companyOwner = Alice.addr;
    vm.startPrank(companyOwner);
    proxyAdmin = address(new ProxyAdmin());

    // 0.- Deploying Mocks
    mockMarketPlace = new MockMgdMarketPlace();

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
    vm.label(address(nft721), "nft721");

    // 2.2- ERC1155
    nftInitData = abi.encodeWithSelector(
      MintGoldDustERC1155.initializeChild.selector, address(company), _TOKEN_URI
    );
    address nft1155Impl = address(new Mgd1155PE());
    nft1155 =
      Mgd1155PE(address(new TransparentUpgradeableProxy(nft1155Impl, proxyAdmin, nftInitData)));
    vm.label(address(nft1155), "nft1155");

    // 2.3 Set mock marketplace in NFTs
    nft721.setMintGoldDustSetPriceAddress(address(mockMarketPlace));
    nft721.setMintGoldDustMarketplaceAuctionAddress(address(mockMarketPlace));
    nft1155.setMintGoldDustSetPriceAddress(address(mockMarketPlace));
    nft1155.setMintGoldDustMarketplaceAuctionAddress(address(mockMarketPlace));

    // 3.- Deploying Escrow
    address escrowImpl = address(new MgdL2NFTEscrow());
    bytes memory escrowInitData =
      abi.encodeWithSelector(MgdL2NFTEscrow.initialize.selector, address(company));
    escrow = MgdL2NFTEscrow(
      address(new TransparentUpgradeableProxy(escrowImpl, proxyAdmin, escrowInitData))
    );
    vm.label(address(escrow), "escrow");

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
    vm.label(address(l2voucher721), "l2voucher721");

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
    vm.label(address(l2voucher1155), "l2voucher1155");

    // 5.- Set Escrow in NFTs
    nft721.setEscrow(address(escrow));
    nft1155.setEscrow(address(escrow));

    // 6.- Set l2 voucher addresses in escrow
    escrow.setVoucherL2(address(l2voucher721), TypeNFT.ERC721);
    escrow.setVoucherL2(address(l2voucher1155), TypeNFT.ERC1155);

    // 7.- Whitelist Bob as artist
    company.whitelist(Bob.addr, true);

    // 8.- Mint NFTs: 2 on Ethereum and 2 on L2; 1 each for 721 and 1155
    vm.startPrank(Bob.addr);
    _721tokenId = nft721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR));
    _1155tokenId = nft1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _EDITIONS, bytes(_MEMOIR));
    nativeVoucherIdFor721 = l2voucher721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR));
    nativeVoucherIdFor1155 =
      l2voucher1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _EDITIONS, bytes(_MEMOIR));

    // 9.- Transfer NFTs to escrow
    vm.recordLogs();
    nft721.transferFrom(Bob.addr, address(escrow), _721tokenId);
    VmSafe.Log[] memory entries721 = vm.getRecordedLogs();
    _721VId = uint256(entries721[3].topics[3]);
    (,, bytes32 blockHash721, MgdL1MarketData memory marketData721) =
      abi.decode(entries721[3].data, (address, uint256, bytes32, MgdL1MarketData));
    vm.recordLogs();
    nft1155.transfer(Bob.addr, address(escrow), _1155tokenId, _EDITIONS);
    VmSafe.Log[] memory entries1155 = vm.getRecordedLogs();
    _1155VId = uint256(entries1155[3].topics[3]);
    (,, bytes32 blockHash1155, MgdL1MarketData memory marketData1155) =
      abi.decode(entries1155[3].data, (address, uint256, bytes32, MgdL1MarketData));
    vm.stopPrank();

    //10. Mint ethereum NFT representations on the L2
    vm.startPrank(L2_CROSSDOMAIN_MESSENGER);
    l2voucher721.setL1NftMintClearance(_721VId, true);
    l2voucher1155.setL1NftMintClearance(_1155VId, true);
    vm.stopPrank();

    l2voucher721.mintL1Nft(_721tokenId, 1, Bob.addr, blockHash721, marketData721);
    l2voucher1155.mintL1Nft(_1155tokenId, _EDITIONS, Bob.addr, blockHash1155, marketData1155);
  }

  function test_validateSetup() public {
    assertEq(nft721.ownerOf(_721tokenId), address(escrow));
    assertEq(nft1155.balanceOf(address(escrow), _1155tokenId), _EDITIONS);
    assertEq(l2voucher721.ownerOf(_721VId), Bob.addr);
    assertEq(l2voucher1155.balanceOf(Bob.addr, _1155VId), _EDITIONS);
    assertEq(l2voucher721.ownerOf(nativeVoucherIdFor721), Bob.addr);
    assertEq(l2voucher1155.balanceOf(Bob.addr, nativeVoucherIdFor1155), _EDITIONS);
  }

  function test_redeemVoucherThatRepresents721() public {
    vm.prank(Bob.addr);
    l2voucher721.redeemVoucherToL1(_721VId, Bob.addr);
    vm.expectRevert();
    // This action reverts because the voucher is burned after redeeming
    l2voucher721.ownerOf(_721VId);
    // Marketdata in L2 must be deleted
    MgdL1MarketData memory updateL2marketData = l2voucher721.getVoucherMarketData(_721VId);
    assertEq(updateL2marketData.artist, address(0));
    assertEq(updateL2marketData.primarySaleL2QuantityToSell, 0);
    assertEq(updateL2marketData.royaltyPercent, 0);
  }

  function test_redeemVoucherThatRepresents1155() public {
    vm.prank(Bob.addr);
    l2voucher1155.redeemVoucherToL1(Bob.addr, _1155VId, _EDITIONS, Bob.addr);
    assertEq(l2voucher1155.balanceOf(Bob.addr, _1155VId), 0);
    // Marketdata in L2 must be deleted
    MgdL1MarketData memory updateL2marketData = l2voucher1155.getVoucherMarketData(_1155VId);
    assertEq(updateL2marketData.artist, address(0));
    assertEq(updateL2marketData.primarySaleL2QuantityToSell, 0);
    assertEq(updateL2marketData.royaltyPercent, 0);
  }

  function test_redeemVoucherThatRepresents1155Partial() public {
    uint40 partialAmount = 2;
    vm.prank(Bob.addr);
    l2voucher1155.redeemVoucherToL1(Bob.addr, _1155VId, partialAmount, Bob.addr);
    assertEq(l2voucher1155.balanceOf(Bob.addr, _1155VId), _EDITIONS - partialAmount);
    // Marketdata in L2 must be updated
    MgdL1MarketData memory updateL2marketData = l2voucher1155.getVoucherMarketData(_1155VId);
    assertEq(updateL2marketData.artist, Bob.addr);
    assertEq(updateL2marketData.primarySaleL2QuantityToSell, _EDITIONS - partialAmount);
    assertEq(updateL2marketData.royaltyPercent, _ROYALTY_PERCENT);
  }

  function test_redeemVoucher721CannotBeDoneByFoe(address foe) public {
    vm.assume(foe != address(0) && foe != Bob.addr && foe != address(l2voucher721));
    vm.prank(foe);
    vm.expectRevert();
    l2voucher721.redeemVoucherToL1(_721VId, Bob.addr);
  }

  function test_redeemVoucher1155CannotBeDoneByFoe(address foe) public {
    vm.assume(foe != address(0) && foe != Bob.addr && foe != address(l2voucher1155));
    vm.prank(foe);
    vm.expectRevert();
    l2voucher1155.redeemVoucherToL1(Bob.addr, _1155VId, _EDITIONS, Bob.addr);
  }

  function test_redeemReceiverCannotBeEscrowOrZeroAddress(address receiver) public {
    vm.startPrank(Bob.addr);
    if (receiver == address(escrow) || receiver == address(0)) {
      vm.expectRevert();
      l2voucher721.redeemVoucherToL1(_721VId, receiver);
      vm.expectRevert();
      l2voucher1155.redeemVoucherToL1(Bob.addr, _1155VId, _EDITIONS, receiver);
    }
    vm.stopPrank();
  }

  function test_redeemVoucher721EventsAndRedeemKey() public {
    MgdL1MarketData memory marketData = l2voucher721.getVoucherMarketData(_721VId);
    (uint256 expectedRedeemKey, bytes32 blockHash) =
      generate_L1RedeemKey(_721VId, address(nft721), _721tokenId, 1, Bob.addr, marketData);

    bytes memory message =
      abi.encodeWithSelector(MgdL2NFTEscrow.setRedeemClearanceKey.selector, expectedRedeemKey, true);
    uint256 nonce = CDMessenger(L2_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    vm.expectEmit(true, false, false, true, L2_CROSSDOMAIN_MESSENGER);
    emit SentMessage(address(escrow), address(l2voucher721), message, nonce, 1_000_000);
    vm.expectEmit(true, false, false, true, address(l2voucher721));
    emit RedeemVoucher(
      _721VId, address(nft721), _721tokenId, 1, Bob.addr, blockHash, marketData, expectedRedeemKey
    );
    uint256 redeemKey = l2voucher721.redeemVoucherToL1(_721VId, Bob.addr);
    assertEq(redeemKey, expectedRedeemKey);
  }

  function test_redeemVoucher1155EventsAndRedeemKey() public {
    MgdL1MarketData memory marketData = l2voucher1155.getVoucherMarketData(_1155VId);
    (uint256 expectedRedeemKey, bytes32 blockHash) = generate_L1RedeemKey(
      _1155VId, address(nft1155), _1155tokenId, _EDITIONS, Bob.addr, marketData
    );

    bytes memory message =
      abi.encodeWithSelector(MgdL2NFTEscrow.setRedeemClearanceKey.selector, expectedRedeemKey, true);
    uint256 nonce = CDMessenger(L2_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    vm.expectEmit(true, false, false, true, L2_CROSSDOMAIN_MESSENGER);
    emit SentMessage(address(escrow), address(l2voucher1155), message, nonce, 1_000_000);
    vm.expectEmit(true, true, true, true, address(l2voucher1155));
    emit RedeemVoucher(
      _1155VId,
      address(nft1155),
      _1155tokenId,
      _EDITIONS,
      Bob.addr,
      blockHash,
      marketData,
      expectedRedeemKey
    );
    uint256 redeemKey = l2voucher1155.redeemVoucherToL1(Bob.addr, _1155VId, _EDITIONS, Bob.addr);
    assertEq(redeemKey, expectedRedeemKey);
  }
}
