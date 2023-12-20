// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC1155Allowance} from "./ERC1155Allowance.sol";

/// @title ERC1155Permit
/// @author Mint Gold Dust LLC
/// @notice This implements the permit function to transfer NFTs using a signature.
/// @dev This implementation is inspired by:
/// https://github.com/primitivefinance/rmm-manager/blob/main/contracts/base/ERC1155Permit.sol
abstract contract ERC1155Permit is ERC1155Allowance {
  // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _TYPE_HASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

  // keccak256("Permit(address owner,address operator,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
  bytes32 private constant _PERMIT_TYPEHASH =
    0x3c6f69a4350f438202c90fe85edf1beb49dd32242963f890cef31487533bec80;

  // keccak("ERC1155Permit");
  bytes32 private constant _HASHED_NAME =
    0x1d4f415bd37d01f3848189b3fd5a293e7415256a90d661a7ca72d2cc50b05eea;

  // keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  // keccak256(abi.encodePacked(owner,tokenId)) => current nonce
  mapping(bytes32 => uint256) internal _nonces;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /**
   *
   * @param owner of the `tokenId`
   * @param operator of given the allowance
   * @param tokenId to give allowance
   * @param amount of `tokenId` to give allowance
   * @param deadline  of the `signature`
   * @param v value of signature
   * @param r value of signature
   * @param s value of signature
   */
  function permit(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
    payable
    virtual;

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
    bytes32 structHash =
      keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, tokenId, amount, nonce, deadline));
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

  function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _blockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }

  function _domainSeparator() private view returns (bytes32) {
    return
      keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
  }

  function _hashedOwnerTokenID(address owner, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(owner, tokenId));
  }
}
