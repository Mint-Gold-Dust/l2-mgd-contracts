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

contract ERC1155PermitTests is CommonSigners, BaseL2Constants, MgdTestConstants, Helpers {
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
    console.log("here");

    company.whitelist(Bob.addr, true);
    bytes memory nftInitData = abi.encodeWithSelector(
      MintGoldDustERC1155.initializeChild.selector, address(company), _TOKEN_URI
    );
    nftImpl = address(new Mgd1155PE());
    nft = Mgd1155PE(address(new TransparentUpgradeableProxy(nftImpl, proxyAdmin, nftInitData)));
    console.log("here2");

    vm.stopPrank();
  }

  function test_properPERMIT_TYPEHASH() public {
    bytes32 expected = keccak256(
      "Permit(address owner,address operator,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    bytes32 actual = nft.PERMIT_TYPEHASH();
    assertEq(actual, expected);
  }

  function test_properDomainSeparator() public {
    bytes32 expected = keccak256(
      abi.encode(
        keccak256(
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        ),
        keccak256("ERC1155Permit"),
        keccak256("v0.0.1"),
        _TEST_CHAIN_ID,
        address(nft)
      )
    );

    bytes32 actual = nft.DOMAIN_SEPARATOR();
    assertEq(actual, expected);
  }

  function test_getPermitDigest(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  )
    public
  {
    bytes32 expected = keccak256(
      abi.encodePacked(
        "\x19\x01",
        nft.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(nft.PERMIT_TYPEHASH(), owner, operator, tokenId, amount, nonce, deadline)
        )
      )
    );

    bytes32 actual = nft.getPermitDigest(owner, operator, tokenId, amount, nonce, deadline);
    assertEq(actual, expected);
  }

  function test_permitUpdatesApproval() public {
    // Mint an NFT for Bob
    vm.prank(Bob.addr);
    uint256 tokenId = nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR));

    // Sign a digest to allow Charlie to spend the NFT
    uint256 nonce = nft.currentNonce(Bob.addr, tokenId);
    uint256 deadline = block.timestamp + 1 hours; // Permit valid for one hour
    bytes32 digest =
      nft.getPermitDigest(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, nonce, deadline);
    (uint8 v, bytes32 r, bytes32 s) = generate_valuesSignature(digest, Bob.privateKey);

    // 'Someone' calls permit to move the NFT from Bob to Charlie
    nft.permit(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, deadline, v, r, s);

    // Assert that Charly is approved to transfer the `_DEFAULT_AMOUNT` NFT
    assertEq(nft.allowance(Bob.addr, Charlie.addr, tokenId), _DEFAULT_AMOUNT);
    // Assert that Charly is NOT approved for all on behalf of Bob
    assertEq(nft.isApprovedForAll(Bob.addr, Charlie.addr), false);
  }

  function test_currentNonceProgresses() public {
    // Mint an NFT for Bob
    vm.prank(Bob.addr);
    uint256 tokenId = nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR));

    // Assert that the current nonce is 0
    assertEq(nft.currentNonce(Bob.addr, tokenId), 0);

    // Sign a digest to allow Charlie to spend the NFT
    uint256 nonce = nft.currentNonce(Bob.addr, tokenId);
    uint256 deadline = block.timestamp + 1 hours; // Permit valid for one hour
    bytes32 digest =
      nft.getPermitDigest(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, nonce, deadline);
    (uint8 v, bytes32 r, bytes32 s) = generate_valuesSignature(digest, Bob.privateKey);

    // 'Someone' calls permit to move the NFT from Bob to Charlie
    nft.permit(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, deadline, v, r, s);

    // Assert that the current nonce is 1
    assertEq(nft.currentNonce(Bob.addr, tokenId), 1);
  }

  function test_permitAndTransfer() public {
    // Mint an NFT for Bob
    vm.prank(Bob.addr);
    uint256 tokenId = nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR));

    // Assert that Bob is the owner of the NFT
    assertEq(nft.balanceOf(Bob.addr, tokenId), _DEFAULT_AMOUNT);

    // Sign a digest to allow Charlie to spend the NFT
    uint256 nonce = nft.currentNonce(Bob.addr, tokenId);
    uint256 deadline = block.timestamp + 1 hours; // Permit valid for one hour
    bytes32 digest =
      nft.getPermitDigest(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, nonce, deadline);
    (uint8 v, bytes32 r, bytes32 s) = generate_valuesSignature(digest, Bob.privateKey);

    // "Someone" calls permit to move the NFT from Bob to Charlie
    nft.permit(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, deadline, v, r, s);

    // Charlie transfers the NFT from Bob to Charlie
    vm.prank(Charlie.addr);
    nft.transfer(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT);

    // Assert that Charlie is the owner of the NFT
    assertEq(nft.balanceOf(Charlie.addr, tokenId), _DEFAULT_AMOUNT);
  }

  function test_permitWithEncodedParamsWorks() public {
    // Mint an NFT for Bob
    vm.prank(Bob.addr);
    uint256 tokenId = nft.mintNft(_TOKEN_URI, _ROYALTY_PERCENT, _DEFAULT_AMOUNT, bytes(_MEMOIR));

    // Assert that Bob is the owner of the NFT
    assertEq(nft.balanceOf(Bob.addr, tokenId), _DEFAULT_AMOUNT);

    // Sign a digest to allow Charlie to spend the NFT
    uint256 nonce = nft.currentNonce(Bob.addr, tokenId);
    uint256 deadline = block.timestamp + 1 hours; // Permit valid for one hour
    bytes32 digest =
      nft.getPermitDigest(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, nonce, deadline);
    (uint8 v, bytes32 r, bytes32 s) = generate_valuesSignature(digest, Bob.privateKey);

    // "Someone" calls permit to move the NFT from Bob to Charlie
    nft.permit(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT, deadline, v, r, s);

    vm.prank(Charlie.addr);
    nft.transfer(Bob.addr, Charlie.addr, tokenId, _DEFAULT_AMOUNT);

    // Assert that Charlie is the owner of the NFT
    assertEq(nft.balanceOf(Charlie.addr, tokenId), _DEFAULT_AMOUNT);
  }
}
