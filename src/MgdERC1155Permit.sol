// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC1155} from "mgd-v2-contracts/MintGoldDustERC1155.sol";
import {MgdCompanyL2Sync, IL1crossDomainMessenger} from "./MgdCompanyL2Sync.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title MgdERC1155Permit
 * @author
 * @notice This contracts extends the L1 {MintGoldDustERC115} contract
 * with functionality that allows to the use of Permit function
 * or signature to transfer an NFT.
 * @dev This contract should upgrade existing {MintGoldDustERC721}:
 * https://github.com/Mint-Gold-Dust/v2-contracts
 * This implementation is inspired by:
 * https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/ERC721Permit.sol
 */
contract MgdERC721Permit is MintGoldDustERC1155 {
  // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _TYPE_HASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

  // keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
  bytes32 private constant _PERMIT_TYPEHASH =
    0x50d6fc6fbe2270eb4d3f1c10a4bff9c8ac65bd8e6af5305a9796cff2597cd7a5;

  // keccak("MgdERC1155Permit");
  bytes32 private constant _HASHED_NAME =
    0xf4ceb8e179a4c9d347b9b9cab99e860f3b7bada8c94797b777888a00c3c4bdc2;

  // keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  // keccak256(abi.encodePacked(owner,tokenId)) => current nonce
  mapping(bytes32 => uint256) internal _nonces;

  // keccak256(abi.encodePacked(owner,spender,tokenId)) => value
  mapping(bytes32 => uint256) internal _allowance;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ___gap;

  function permit(
    address owner,
    address spender,
    uint256 tokenId,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    external
    payable
    override
  {
    require(_blockTimestamp() <= deadline, "Permit expired");

    // bytes32 digest = getPermitDigest(spender, tokendId, _getAndIncrementNonce(tokenId), deadline);
    // require(spender != owner, "ERC1155Permit: approval to current owner");

    // if (Address.isContract(owner)) {
    //   require(
    //     IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
    //     "Unauthorized"
    //   );
    // } else {
    //   address recoveredAddress = ECDSA.recover(digest, v, r, s);
    //   require(recoveredAddress != address(0), "Invalid signature");
    //   require(recoveredAddress == owner, "Unauthorized");
    // }

    // _approve(spender, tokenId);
  }

  function PERMIT_TYPEHASH() external pure returns (bytes32) {
    return _PERMIT_TYPEHASH;
  }

  function getPermitDigest(
    address owner,
    address spender,
    uint256 tokenId,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  )
    public
    view
    returns (bytes32 digest)
  {
    bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, tokenId, amount, nonce, deadline));
    digest = _hashTypedData(structHash);
  }

  function currentNonce(address owner, uint256 tokenId) public view returns (uint256 current) {
    current = _nonces[_hashedOwnerTokenID(owner, tokenId)];
  }

  function _getAndIncrementNonce(address owner, uint256 tokenId) internal returns (uint256 current) {
    bytes32 hashed = _hashedOwnerTokenID(owner, tokenId);
    current = _nonces[hashed];
    _nonces[hashed] += 1;
  }

  function _hashTypedData(bytes32 structHash) private view virtual returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _domainSeparator() private view returns (bytes32) {
    return
      keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
  }

  function _blockTimestamp() private view returns (uint256) {
    return block.timestamp;
  }

  function _hashedOwnerTokenID(address owner, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(owner, tokenId));
  }
}
