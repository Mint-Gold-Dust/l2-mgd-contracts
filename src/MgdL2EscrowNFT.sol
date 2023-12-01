// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

struct NFTEscrowData {
  uint256 amount;
  bytes32 voucherIdL2;
}

/// @title MGDL2EscrowNFT
/// @notice An extension to ERC721 or ERC1155 allowing to block transfers of an NFT
/// due to activity in a L2. This allows for NFTs to be locked for `transfers` without
/// trigering transfer events or displaying a different `owner`.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
abstract contract MgdL2EscrowNFT {
  /// events
  event EnterEscrow(uint256 indexed tokenId, uint256 amount);
  event ReleasedEscrow(uint256 indexed tokenId, uint256 amount);

  /// address => nonce
  mapping(address => uint256) internal _nonces;

  /// tokenId => NFTEscrowData
  mapping(uint256 => NFTEscrowData) public escrowedTokenId;

  /**
   * @dev Requirements:
   * - Msg.sender is the owner of `tokenId` or check signature.
   */
  function placeIntoEscrow(
    uint256 tokenId,
    uint256 amount
  )
    external
    virtual
    returns (bytes32 voucherIdL2);

  /**
   * @dev Requirements:
   * - Must be called by {MgdCompanyL2Sync.crossDomainMessenger}
   */
  function releaseFromEscrow(uint256 tokenId, uint256 amount) external virtual;
  function updateEscrowedOwner(uint256 tokenId) external virtual;

  function _generateVoucherId(
    uint256 tokenId,
    uint256 amount,
    address owner
  )
    internal
    view
    returns (bytes32)
  {
    return keccak256(abi.encode(tokenId, amount, owner, blockhash(block.number - 1)));
  }
}
