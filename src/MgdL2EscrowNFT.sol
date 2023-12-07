// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSAUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

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

  bytes32 private constant _TYPE_HASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  bytes32 internal constant _PLACE_INTO_ESCROW_TYPEHASH =
    keccak256("PlaceIntoEscrow(uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)");

  // bytes32 private constant _HASHED_NAME = keccak("MgdL2EscrowNFT");
  bytes32 private constant _HASHED_NAME =
    0x62a7bfc8f539cc78f3d488153631bee625aaf9bdaa4a89fe83c4792b0d8534ef;
  // bytes32 private constant  _HASHED_VERSION = keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  /// address => nonce
  mapping(address => uint256) internal _nonces;

  /// tokenId => NFTEscrowData
  mapping(uint256 => NFTEscrowData) public escrowedTokenId;

  address public nftL2Voucher;

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
   * - `ownerSignature` is the owner of `tokenId`.
   */
  function placeIntoEscrow(
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    bytes32 ownerSignature
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

  function getPlaceIntoEscrowDigest(
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
      keccak256(abi.encode(_PLACE_INTO_ESCROW_TYPEHASH, tokenId, amount, nonce, deadline));
    digest = _hashTypedDataV4(structHash);
  }

  function currentNonce(address owner) public view returns (uint256 current) {
    current = _nonces[owner];
  }

  function _useNonce(address owner) internal returns (uint256 current) {
    current = currentNonce(owner);
    _nonces[owner] += 1;
  }

  /**
   * @dev Returns the domain separator for mainnet ONLY signed messages for the {MintGoldDustCompany}
   * contract address that relays admin changes to any L2.
   *
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    return
      keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
  }

  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSAUpgradeable.toTypedDataHash(_domainSeparatorV4(), structHash);
  }

  function _generateVoucherId(
    uint256 tokenId,
    uint256 amount,
    address owner
  )
    internal
    view
    returns (bytes32)
  {
    bytes32 salt = blockhash(block.number - 1);
    return keccak256(abi.encode(tokenId, amount, owner, currentNonce(owner), salt));
  }

  function _sendL2EscrowNotice(address nft, uint256 amount, bytes32 voucherId) internal virtual;
}
