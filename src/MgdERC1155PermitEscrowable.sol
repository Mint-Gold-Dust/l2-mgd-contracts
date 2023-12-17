// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC1155} from "mgd-v2-contracts/MintGoldDustERC1155.sol";
import {ERC1155Permit, ERC1155Allowance} from "./abstract/ERC1155Permit.sol";
import {
  ERC1155Upgradeable,
  IERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {MgdCompanyL2Sync, ICrossDomainMessenger} from "./MgdCompanyL2Sync.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MgdL1NFTData} from "./abstract/MgdL2NFT.sol";

/**
 * @title MgdERC1155PermitEscrowable
 * @author Mint Gold Dust LLC
 * @notice This contracts extends the L1 {MintGoldDustERC1155} contract
 * with functionality that allows usage of permit and proper information
 * to move NFTs into escrow.
 * @dev This contract should upgrade existing {MintGoldDustERC1155}:
 * https://github.com/Mint-Gold-Dust/v2-contracts
 */
contract MgdERC1155PermitEscrowable is MintGoldDustERC1155, ERC1155Permit {
  // Events
  /**
   * @dev Emit when `escrow` address is set.
   */
  event SetEscrow(address esccrow_);

  address public escrow;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Overriden to utilize the allowance in {ERC1155Allowance} set up in this contract.
  /// Requirements:
  /// - If using from != caller, and is not approved for all, call `_spendAllowance`
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  )
    public
    override
  {
    address operator = msg.sender;
    require(
      from == operator || getAllowance(from, operator, id) >= amount,
      "ERC1155: caller is not owner or approved or has allowance"
    );
    if (from != operator && !isApprovedForAll(from, operator)) {
      _spendAllowance(from, operator, id, amount);
    }
    if (escrow != address(0) && to == escrow) {
      data = getTokenIdData(id, amount);
    }
    _safeTransferFrom(from, to, id, amount, data);
  }

  /// @inheritdoc ERC1155Allowance
  function getAllowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    public
    view
    override
    returns (uint256)
  {
    if (isApprovedForAll(owner, operator)) {
      return type(uint256).max;
    } else {
      return _getAllowance(owner, operator, tokenId);
    }
  }

  /// @inheritdoc ERC1155Permit
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
    override
  {
    require(_blockTimestamp() <= deadline, "Permit expired");
    require(balanceOf(owner, tokenId) >= amount, "Invalid amount");
    require(operator != owner, "ERC1155Permit: approval to current owner");

    bytes32 digest = getPermitDigest(
      owner, operator, tokenId, amount, _getAndIncrementNonce(owner, tokenId), deadline
    );

    if (Address.isContract(owner)) {
      require(
        IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
        "Unauthorized"
      );
    } else {
      address recoveredAddress = ECDSA.recover(digest, v, r, s);
      require(recoveredAddress != address(0), "Invalid signature");
      require(recoveredAddress == owner, "Unauthorized");
    }

    _setAllowance(owner, operator, tokenId, amount);
  }

  /**
   * @notice Common entry external function for the `permit()` function.
   *
   * @param params abi.encoded inputs for this.permit() public
   */
  function permit(bytes calldata params) external payable {
    (
      address owner,
      address operator,
      uint256 tokenId,
      uint256 amount,
      uint256 deadline,
      uint8 v,
      bytes32 r,
      bytes32 s
    ) = abi.decode(params, (address, address, uint256, uint256, uint256, uint8, bytes32, bytes32));
    permit(owner, operator, tokenId, amount, deadline, v, r, s);
  }

  function setEscrow(address escrow_) external isZeroAddress(escrow_) isowner {
    escrow = escrow_;
    emit SetEscrow(escrow_);
  }

  function getTokenIdData(
    uint256 tokenId,
    uint256 amount
  )
    public
    view
    virtual
    returns (bytes memory data)
  {
    // TODO safe number casting
    data = abi.encode(
      MgdL1NFTData({
        artist: tokenIdArtist[tokenId],
        hasCollabs: hasTokenCollaborators[tokenId],
        tokenWasSold: tokenWasSold[tokenId],
        collabsQuantity: uint40(tokenIdCollaboratorsQuantity[tokenId]),
        primarySaleQuantityToSell: uint40(primarySaleQuantityToSold[tokenId]),
        representedAmount: uint128(amount),
        royaltyPercent: uint128(tokenIdRoyaltyPercent[tokenId]),
        collabs: tokenCollaborators[tokenId],
        collabsPercentage: tokenIdCollaboratorsPercentage[tokenId]
      })
    );
  }
}
