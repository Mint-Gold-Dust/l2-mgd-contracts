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
import {MgdL2NFTEscrow} from "../../src/MgdL2NFTEscrow.sol";

contract EscrowingTests is CommonSigners, BaseL2Constants, MgdTestConstants {
  /// addresses
  address public proxyAdmin;

  Mgd721PE public nft721;
  Mgd1155PE public nft1155;
  MgdL2NFTEscrow public escrow;

  MgdCompanyL2Sync public company;
  address public companyOwner;

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
}
