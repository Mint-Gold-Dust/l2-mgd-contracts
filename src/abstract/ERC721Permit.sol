// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title ERC721Permit
/// @author Mint Gold Dust LLC
/// @notice This implements the permit function to transfer NFTs using a signature.
/// @dev This implementation is inspired by:
/// https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/ERC721Permit.sol
abstract contract ERC721Permit {
  // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _TYPE_HASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

  // keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)")
  bytes32 private constant _PERMIT_TYPEHASH =
    0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

  // keccak("ERC721Permit");
  bytes32 private constant _HASHED_NAME =
    0xb8a9b316c4557095380e2f24fb0a02b2c05d6a5d7333e497cc62196fbf2880fc;

  // keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  // tokenId => current nonce
  mapping(uint256 => uint256) internal _nonces;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  function permit(
    address spender,
    uint256 tokenId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
    payable
    virtual;

  /**
   * @notice The permit typehash used in the permit signature
   */
  function PERMIT_TYPEHASH() public pure returns (bytes32) {
    return _PERMIT_TYPEHASH;
  }

  /**
   * @notice The domain separator used in the permit signature
   */
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return _domainSeparator();
  }

  function getPermitDigest(
    address spender,
    uint256 tokenId,
    uint256 nonce,
    uint256 deadline
  )
    public
    view
    returns (bytes32 digest)
  {
    bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, spender, tokenId, nonce, deadline));
    digest = _hashTypedData(structHash);
  }

  function currentNonce(uint256 tokenId) public view returns (uint256 current) {
    current = _nonces[tokenId];
  }

  function _getAndIncrementNonce(uint256 tokenId) internal returns (uint256 current) {
    current = currentNonce(tokenId);
    _nonces[tokenId] += 1;
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
}
