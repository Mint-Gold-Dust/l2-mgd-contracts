// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants, CDMessenger} from "./op-stack/BaseL2Constants.t.sol";
import {MgdTestConstants} from "./utils/MgdTestConstants.t.sol";
import {Helpers} from "./utils/Helpers.t.sol";

import {MockMgdMarketPlace, ManagePrimarySale} from "../mocks/MockMgdMarketPlace.sol";

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
import {MgdL2BaseNFT, MgdL2BaseVoucher} from "../../src/voucher/MgdL2BaseVoucher.sol";
import {MgdCompanyL2Sync, MintGoldDustCompany} from "../../src/MgdCompanyL2Sync.sol";
import {MgdL1MarketData, TypeNFT} from "../../src/voucher/VoucherDataTypes.sol";
import {MgdL2NFTEscrow} from "../../src/MgdL2NFTEscrow.sol";
import {Mgd721L2Voucher} from "../../src/voucher/Mgd721L2Voucher.sol";
import {Mgd1155L2Voucher} from "../../src/voucher/Mgd1155L2Voucher.sol";

contract ReceivingL2EscrowNoticeTests is CommonSigners, BaseL2Constants, MgdTestConstants, Helpers {
  // Test events
  event L1NftMintClearance(uint256 indexed voucherId, bool state);
  event L1NftMinted(uint256 indexed voucherId);

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

  uint256[] private _721tokenIdsOfBob;
  uint256[] private _1155tokenIdsOfBob;

  // Mocks
  MockMgdMarketPlace public mockMarketPlace;

  function setUp() public {
    // 0.- Deploying Mocks
    mockMarketPlace = new MockMgdMarketPlace();

    // 1.- Deploying company
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

    // 4.- Deploying L2 Vouchers (pretended to be on a different chain to simplify tests)

    // 4.1- 721 Voucher
    address l2voucher721Impl = address(new Mgd721L2Voucher());
    bytes memory l2voucher721InitData = abi.encodeWithSelector(
      Mgd721L2Voucher.initialize.selector,
      address(company),
      address(escrow),
      address(nft721),
      L2_CROSSDOMAIN_MESSENGER
    );
    l2voucher721 = Mgd721L2Voucher(
      address(new TransparentUpgradeableProxy(l2voucher721Impl, proxyAdmin, l2voucher721InitData))
    );

    // 4.2- 1155 Voucher
    address l2voucher1155Impl = address(new Mgd1155L2Voucher());
    bytes memory l2voucher1155InitData = abi.encodeWithSelector(
      Mgd1155L2Voucher.initialize.selector,
      address(company),
      address(escrow),
      address(nft1155),
      L2_CROSSDOMAIN_MESSENGER
    );
    l2voucher1155 = Mgd1155L2Voucher(
      address(new TransparentUpgradeableProxy(l2voucher1155Impl, proxyAdmin, l2voucher1155InitData))
    );

    // 5.- Set Escrow in NFTs
    nft721.setEscrow(address(escrow));
    nft1155.setEscrow(address(escrow));

    // 5.1 Set mock marketplace in NFTs
    nft721.setMintGoldDustSetPriceAddress(address(mockMarketPlace));
    nft721.setMintGoldDustMarketplaceAuctionAddress(address(mockMarketPlace));
    nft1155.setMintGoldDustSetPriceAddress(address(mockMarketPlace));
    nft1155.setMintGoldDustMarketplaceAuctionAddress(address(mockMarketPlace));

    // 6.- Set l2 voucher addresses in escrow
    escrow.setVoucherL2(address(l2voucher721), TypeNFT.ERC721);
    escrow.setVoucherL2(address(l2voucher1155), TypeNFT.ERC1155);

    // 7.- Whitelist Bob as artist
    company.whitelist(Bob.addr, true);

    vm.stopPrank();

    // 8.- Bob Mints some NFTs
    vm.startPrank(Bob.addr);
    _721tokenIdsOfBob.push(nft721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR)));
    _1155tokenIdsOfBob.push(nft1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 10, bytes(_MEMOIR)));
    vm.stopPrank();
  }

  function test_receivingEscrowNoticeOn721L2Voucher() public {
    uint256 tokenId = _721tokenIdsOfBob[0];

    MgdL1MarketData memory marketData = structure_tokenIdData(nft721.getTokenIdData(tokenId));
    (uint256 voucherId,) =
      generate_L1EscrowedIdentifier(address(nft721), tokenId, 1, Bob.addr, marketData);

    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft721.safeTransferFrom(Bob.addr, address(escrow), tokenId);

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher721), 0, 1_000_000, message
    );
    assertEq(l2voucher721.mintCleared(voucherId), true);
  }

  function test_receivingEscrowNoticeOn1155L2Voucher() public {
    uint256 tokenId = _1155tokenIdsOfBob[0];
    uint40 amountToEscrow = 5;

    MgdL1MarketData memory marketData =
      structure_tokenIdData(nft1155.getTokenIdData(tokenId, amountToEscrow));
    (uint256 voucherId,) =
      generate_L1EscrowedIdentifier(address(nft1155), tokenId, amountToEscrow, Bob.addr, marketData);

    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft1155.safeTransferFrom(Bob.addr, address(escrow), tokenId, amountToEscrow, "");

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher1155), 0, 1_000_000, message
    );
    assertEq(l2voucher1155.mintCleared(voucherId), true);
  }

  function test_voucher721CallerToClearEscrow(address foe) public {
    vm.assume(foe != address(0) && foe != proxyAdmin);
    uint256 voucherId = 1234;
    if (foe != L2_CROSSDOMAIN_MESSENGER && foe != address(company)) {
      vm.prank(foe);
      vm.expectRevert(MgdL2BaseVoucher.MgdL2BaseVoucher__onlyCrossAuthorized_notAllowed.selector);
      l2voucher721.setL1NftMintClearance(voucherId, true);
      assertEq(l2voucher721.mintCleared(voucherId), false);
    } else {
      vm.prank(foe);
      l2voucher721.setL1NftMintClearance(voucherId, true);
      assertEq(l2voucher721.mintCleared(voucherId), true);
    }
  }

  function test_voucher1155CallerToClearEscrow(address foe) public {
    vm.assume(foe != address(0) && foe != proxyAdmin);
    uint256 voucherId = 1234;
    if (foe != L2_CROSSDOMAIN_MESSENGER && foe != address(company)) {
      vm.prank(foe);
      vm.expectRevert(MgdL2BaseVoucher.MgdL2BaseVoucher__onlyCrossAuthorized_notAllowed.selector);
      l2voucher1155.setL1NftMintClearance(voucherId, true);
      assertEq(l2voucher1155.mintCleared(voucherId), false);
    } else {
      vm.prank(foe);
      l2voucher1155.setL1NftMintClearance(voucherId, true);
      assertEq(l2voucher1155.mintCleared(voucherId), true);
    }
  }

  function test_mint721VoucherClearanceEvents() public {
    uint256 voucherId = 1234;
    vm.prank(L2_CROSSDOMAIN_MESSENGER);
    vm.expectEmit(true, false, false, true, address(l2voucher721));
    emit L1NftMintClearance(voucherId, true);
    l2voucher721.setL1NftMintClearance(voucherId, true);
    assertEq(l2voucher721.mintCleared(voucherId), true);
  }

  function test_mint1155VoucherClearanceEvents() public {
    uint256 voucherId = 1234;
    vm.prank(L2_CROSSDOMAIN_MESSENGER);
    vm.expectEmit(true, false, false, true, address(l2voucher1155));
    emit L1NftMintClearance(voucherId, true);
    l2voucher1155.setL1NftMintClearance(voucherId, true);
    assertEq(l2voucher1155.mintCleared(voucherId), true);
  }

  function test_minting721VoucherAfterClearance() public {
    uint256 tokenId = _721tokenIdsOfBob[0];

    MgdL1MarketData memory marketData = structure_tokenIdData(nft721.getTokenIdData(tokenId));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft721), tokenId, 1, Bob.addr, marketData);

    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft721.safeTransferFrom(Bob.addr, address(escrow), tokenId);

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher721), 0, 1_000_000, message
    );
    assertEq(l2voucher721.mintCleared(voucherId), true);

    l2voucher721.mintVoucherFromL1Nft(tokenId, 1, Bob.addr, blockHash, marketData);

    assertEq(l2voucher721.ownerOf(voucherId), Bob.addr);
    assertEq(l2voucher721.mintCleared(voucherId), false);

    MgdL1MarketData memory savedMarketData = l2voucher721.getVoucherMarketData(voucherId);
    assertEq(savedMarketData.artist, marketData.artist);
    assertEq(savedMarketData.hasCollabs, marketData.hasCollabs);
    assertEq(savedMarketData.tokenWasSold, marketData.tokenWasSold);
    assertEq(savedMarketData.collabsQuantity, marketData.collabsQuantity);
    assertEq(savedMarketData.primarySaleL2QuantityToSell, marketData.primarySaleL2QuantityToSell);
    assertEq(savedMarketData.royaltyPercent, marketData.royaltyPercent);
    assertEq(savedMarketData.collabs[0], marketData.collabs[0]);
    assertEq(savedMarketData.collabs[1], marketData.collabs[1]);
    assertEq(savedMarketData.collabs[2], marketData.collabs[2]);
    assertEq(savedMarketData.collabs[3], marketData.collabs[3]);
    assertEq(savedMarketData.collabsPercentage[0], marketData.collabsPercentage[0]);
    assertEq(savedMarketData.collabsPercentage[1], marketData.collabsPercentage[1]);
    assertEq(savedMarketData.collabsPercentage[2], marketData.collabsPercentage[2]);
    assertEq(savedMarketData.collabsPercentage[3], marketData.collabsPercentage[3]);
    assertEq(savedMarketData.collabsPercentage[4], marketData.collabsPercentage[4]);
  }

  function test_minting1155VoucherAfterClearance() public {
    uint256 tokenId = _1155tokenIdsOfBob[0];
    uint40 amountToEscrow = 5;

    MgdL1MarketData memory marketData =
      structure_tokenIdData(nft1155.getTokenIdData(tokenId, amountToEscrow));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft1155), tokenId, amountToEscrow, Bob.addr, marketData);

    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft1155.safeTransferFrom(Bob.addr, address(escrow), tokenId, amountToEscrow, "");

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher1155), 0, 1_000_000, message
    );
    assertEq(l2voucher1155.mintCleared(voucherId), true);

    l2voucher1155.mintVoucherFromL1Nft(tokenId, amountToEscrow, Bob.addr, blockHash, marketData);

    assertEq(l2voucher1155.balanceOf(Bob.addr, voucherId), amountToEscrow);
    assertEq(l2voucher1155.mintCleared(voucherId), false);

    MgdL1MarketData memory savedMarketData = l2voucher1155.getVoucherMarketData(voucherId);
    assertEq(savedMarketData.artist, marketData.artist);
    assertEq(savedMarketData.hasCollabs, marketData.hasCollabs);
    assertEq(savedMarketData.tokenWasSold, marketData.tokenWasSold);
    assertEq(savedMarketData.collabsQuantity, marketData.collabsQuantity);
    assertEq(savedMarketData.primarySaleL2QuantityToSell, marketData.primarySaleL2QuantityToSell);
    assertEq(savedMarketData.royaltyPercent, marketData.royaltyPercent);
    assertEq(savedMarketData.collabs[0], marketData.collabs[0]);
    assertEq(savedMarketData.collabs[1], marketData.collabs[1]);
    assertEq(savedMarketData.collabs[2], marketData.collabs[2]);
    assertEq(savedMarketData.collabs[3], marketData.collabs[3]);
    assertEq(savedMarketData.collabsPercentage[0], marketData.collabsPercentage[0]);
    assertEq(savedMarketData.collabsPercentage[1], marketData.collabsPercentage[1]);
    assertEq(savedMarketData.collabsPercentage[2], marketData.collabsPercentage[2]);
    assertEq(savedMarketData.collabsPercentage[3], marketData.collabsPercentage[3]);
    assertEq(savedMarketData.collabsPercentage[4], marketData.collabsPercentage[4]);
  }

  function test_tryMintingVoucher721AfterClearanceTwiceReverts() public {
    uint256 tokenId = _721tokenIdsOfBob[0];
    MgdL1MarketData memory marketData = structure_tokenIdData(nft721.getTokenIdData(tokenId));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft721), tokenId, 1, Bob.addr, marketData);
    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft721.safeTransferFrom(Bob.addr, address(escrow), tokenId);

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher721), 0, 1_000_000, message
    );
    l2voucher721.mintVoucherFromL1Nft(tokenId, 1, Bob.addr, blockHash, marketData);

    vm.expectRevert(MgdL2BaseVoucher.MgdL2BaseVoucher__mintL1Nft_notClearedOrAlreadyMinted.selector);
    l2voucher721.mintVoucherFromL1Nft(tokenId, 1, Bob.addr, blockHash, marketData);
  }

  function test_tryMintingVoucher1155AfterClearanceTwiceReverts() public {
    uint256 tokenId = _1155tokenIdsOfBob[0];
    uint40 amountToEscrow = 5;

    MgdL1MarketData memory marketData =
      structure_tokenIdData(nft1155.getTokenIdData(tokenId, amountToEscrow));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft1155), tokenId, amountToEscrow, Bob.addr, marketData);
    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft1155.safeTransferFrom(Bob.addr, address(escrow), tokenId, amountToEscrow, "");

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher1155), 0, 1_000_000, message
    );
    l2voucher1155.mintVoucherFromL1Nft(tokenId, amountToEscrow, Bob.addr, blockHash, marketData);

    vm.expectRevert(MgdL2BaseVoucher.MgdL2BaseVoucher__mintL1Nft_notClearedOrAlreadyMinted.selector);
    l2voucher1155.mintVoucherFromL1Nft(tokenId, amountToEscrow, Bob.addr, blockHash, marketData);
  }

  function test_minting721VoucherAfterClearanceEvent() public {
    uint256 tokenId = _721tokenIdsOfBob[0];
    MgdL1MarketData memory marketData = structure_tokenIdData(nft721.getTokenIdData(tokenId));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft721), tokenId, 1, Bob.addr, marketData);
    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft721.safeTransferFrom(Bob.addr, address(escrow), tokenId);

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher721), 0, 1_000_000, message
    );

    vm.expectEmit(true, false, false, true, address(l2voucher721));
    emit L1NftMinted(voucherId);
    l2voucher721.mintVoucherFromL1Nft(tokenId, 1, Bob.addr, blockHash, marketData);
  }

  function test_minting1155VoucherAfterClearanceEvent() public {
    uint256 tokenId = _1155tokenIdsOfBob[0];
    uint40 amountToEscrow = 5;

    MgdL1MarketData memory marketData =
      structure_tokenIdData(nft1155.getTokenIdData(tokenId, amountToEscrow));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft1155), tokenId, amountToEscrow, Bob.addr, marketData);
    bytes memory message =
      abi.encodeWithSelector(MgdL2BaseVoucher.setL1NftMintClearance.selector, voucherId, true);
    uint256 nonce = CDMessenger(L1_CROSSDOMAIN_MESSENGER).messageNonce();

    vm.prank(Bob.addr);
    nft1155.safeTransferFrom(Bob.addr, address(escrow), tokenId, amountToEscrow, "");

    CDMessenger(L2_CROSSDOMAIN_MESSENGER).relayMessage(
      nonce, address(escrow), address(l2voucher1155), 0, 1_000_000, message
    );

    vm.expectEmit(true, false, false, true, address(l2voucher1155));
    emit L1NftMinted(voucherId);
    l2voucher1155.mintVoucherFromL1Nft(tokenId, amountToEscrow, Bob.addr, blockHash, marketData);
  }
}
