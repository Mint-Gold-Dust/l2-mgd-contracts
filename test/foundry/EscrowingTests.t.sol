// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {CommonSigners} from "./utils/CommonSigners.t.sol";
import {BaseL2Constants} from "./op-stack/BaseL2Constants.t.sol";
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
import {MgdL2NFTEscrow, MgdL1MarketData} from "../../src/MgdL2NFTEscrow.sol";

contract EscrowingTests is CommonSigners, BaseL2Constants, MgdTestConstants {
  // Test events
  event EnterEscrow(
    address nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed voucherId
  );

  /// addresses
  address public proxyAdmin;

  Mgd721PE public nft721;
  Mgd1155PE public nft1155;
  MgdL2NFTEscrow public escrow;

  MgdCompanyL2Sync public company;
  address public companyOwner;

  address public constant MOCK_L2_VOUCHER = 0x000000000000000000000000000000000000fafa;

  /// Local constants: mock data to mint NFTs
  string private constant _TOKEN_URI = "https://ipfs.nowhere.example/";
  uint256 private constant _ROYALTY_PERCENT = 10;
  uint256 private constant _DEFAULT_AMOUNT = 100; // For ERC1155
  string private constant _MEMOIR = "A memoir";

  uint256[] private _721tokenIdsOfBob;
  uint256[] private _1155tokenIdsOfBob;

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

    // 4.- Set Escrow in NFTs
    nft721.setEscrow(address(escrow));
    nft1155.setEscrow(address(escrow));

    // 5.- Whitelist Bob as artist
    company.whitelist(Bob.addr, true);

    vm.stopPrank();

    // 6.- Bob Mints some NFTs
    vm.startPrank(Bob.addr);
    _1155tokenIdsOfBob.push(
      nft1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR))
    );
    _1155tokenIdsOfBob.push(
      nft1155.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR))
    );
    _721tokenIdsOfBob.push(nft721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR)));
    _721tokenIdsOfBob.push(nft721.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, 1, bytes(_MEMOIR)));
    vm.stopPrank();
  }

  function test_escrowIsSetInNFTs() public {
    assertEq(address(nft721.escrow()), address(escrow));
    assertEq(address(nft1155.escrow()), address(escrow));
  }

  function test_nft721TransferToEscrow() public {
    // 0.- Check that Bob's NFTs are in his wallet
    assertEq(nft721.ownerOf(_721tokenIdsOfBob[0]), Bob.addr);
    assertEq(nft721.ownerOf(_721tokenIdsOfBob[1]), Bob.addr);

    // 1.- Bob transfers his NFTs to escrow
    vm.startPrank(Bob.addr);
    nft721.transferFrom(Bob.addr, address(escrow), _721tokenIdsOfBob[0]);
    nft721.safeTransferFrom(Bob.addr, address(escrow), _721tokenIdsOfBob[1]);
    vm.stopPrank();

    // 2.- Check that Bob's NFTs are in escrow
    assertEq(nft721.ownerOf(_721tokenIdsOfBob[0]), address(escrow));
    assertEq(nft721.ownerOf(_721tokenIdsOfBob[1]), address(escrow));
  }

  function test_nft1155TransferToEscrow() public {
    uint256 halfDefaultAmount = _DEFAULT_AMOUNT / 2;
    // 0.- Check that Bob's NFTs are in his wallet
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[0]), _DEFAULT_AMOUNT);
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[1]), _DEFAULT_AMOUNT);

    // 1.- Bob transfers his NFTs to escrow
    vm.startPrank(Bob.addr);
    nft1155.safeTransferFrom(
      Bob.addr, address(escrow), _1155tokenIdsOfBob[0], halfDefaultAmount, ""
    );
    nft1155.safeTransferFrom(
      Bob.addr, address(escrow), _1155tokenIdsOfBob[1], halfDefaultAmount, ""
    );
    vm.stopPrank();

    // 2.- Check that Bob's NFTs are in escrow
    assertEq(nft1155.balanceOf(address(escrow), _1155tokenIdsOfBob[0]), halfDefaultAmount);
    assertEq(nft1155.balanceOf(address(escrow), _1155tokenIdsOfBob[1]), halfDefaultAmount);
  }

  function test_nft1155UsingBatchTransferToEscrow() public {
    uint256 halfDefaultAmount = _DEFAULT_AMOUNT / 2;
    // 0.- Check that Bob's NFTs are in his wallet
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[0]), _DEFAULT_AMOUNT);
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[1]), _DEFAULT_AMOUNT);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = halfDefaultAmount;
    amounts[1] = halfDefaultAmount;

    // 1.- Bob tries transfering his NFTs to escrow using batch transfer
    vm.prank(Bob.addr);
    vm.expectRevert("ERC1155: transfer to non-ERC1155Receiver implementer");
    nft1155.safeBatchTransferFrom(Bob.addr, address(escrow), _1155tokenIdsOfBob, amounts, "");

    // 2.- Check that Bob's NFTs are still in his possession
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[0]), _DEFAULT_AMOUNT);
    assertEq(nft1155.balanceOf(Bob.addr, _1155tokenIdsOfBob[1]), _DEFAULT_AMOUNT);
  }

  function test_nft721TransferToEscrowEvent() public {
    uint256 tokenId = _721tokenIdsOfBob[0];

    MgdL1MarketData memory marketData = structure_tokenIdData(nft721.getTokenIdData(tokenId));
    (uint256 voucherId, bytes32 blockHash) =
      generate_L1EscrowedIdentifier(address(nft721), tokenId, 1, Bob.addr, marketData);

    // 1.- Bob transfers his NFTs to escrow
    vm.prank(Bob.addr);
    vm.expectEmit(true, true, true, true, address(escrow));
    emit EnterEscrow(address(nft721), tokenId, 1, Bob.addr, blockHash, marketData, voucherId);
    nft721.safeTransferFrom(Bob.addr, address(escrow), tokenId);
  }

  function test_nft1155TransferToEscrowEvent() public {
    uint256 tokenId = _1155tokenIdsOfBob[0];
    uint256 halfDefaultAmount = _DEFAULT_AMOUNT / 2;

    MgdL1MarketData memory marketData = structure_tokenIdData(nft1155.getTokenIdData(tokenId));
    (uint256 voucherId, bytes32 blockHash) = generate_L1EscrowedIdentifier(
      address(nft1155), tokenId, halfDefaultAmount, Bob.addr, marketData
    );

    // 1.- Bob transfers his NFTs to escrow
    vm.prank(Bob.addr);
    vm.expectEmit(true, true, true, true, address(escrow));
    emit EnterEscrow(
      address(nft1155), tokenId, halfDefaultAmount, Bob.addr, blockHash, marketData, voucherId
    );
    nft1155.safeTransferFrom(Bob.addr, address(escrow), tokenId, halfDefaultAmount, "");
  }

  function structure_tokenIdData(bytes memory tokenIdData)
    private
    pure
    returns (MgdL1MarketData memory marketData)
  {
    (
      marketData.artist,
      marketData.hasCollabs,
      marketData.tokenWasSold,
      marketData.collabsQuantity,
      marketData.primarySaleQuantityToSell,
      marketData.royaltyPercent,
      marketData.collabs,
      marketData.collabsPercentage
    ) = abi.decode(
      tokenIdData, (address, bool, bool, uint40, uint40, uint256, address[4], uint256[5])
    );
  }

  function generate_L1EscrowedIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    MgdL1MarketData memory marketData
  )
    private
    view
    returns (uint256 voucherId, bytes32 blockHash)
  {
    blockHash = blockhash(block.number);
    voucherId = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, marketData)));
  }
}
