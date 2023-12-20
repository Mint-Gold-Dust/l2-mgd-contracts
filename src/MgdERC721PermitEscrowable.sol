// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC721} from "mgd-v2-contracts/MintGoldDustERC721.sol";
import {ERC721Permit, ECDSA} from "./abstract/ERC721Permit.sol";
import {
  ERC721Upgradeable,
  IERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MgdL1MarketData} from "./abstract/MgdL2Voucher.sol";

/**
 * @title MgdERC721PermitEscrowable
 * @author Mint Gold Dust LLC
 * @notice This contracts extends the L1 {MintGoldDustERC721} contract
 * with functionality that allows usage of permit and proper information
 * to move NFTs into escrow.
 * @dev This contract should upgrade existing {MintGoldDustERC721}:
 * https://github.com/Mint-Gold-Dust/v2-contracts
 */
contract MgdERC721PermitEscrowable is MintGoldDustERC721, ERC721Permit {
  /// Events
  /**
   * @dev Emit when `escrow` address is set.
   */
  event SetEscrow(address esccrow_);

  /**
   * @dev Emit when `escrow` address is set.
   */
  event EscrowUpdateMarketData(uint256 indexed tokenId, MgdL1MarketData marketData);

  /// Custom Errors
  error MgdERC721PermitEscrowable__onlyEscrow_notAllowed();

  address public escrow;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Overriden to include `data` from `_getTokenIdData` to send when sending to `escrow` address.
  /// @dev CAUTION! If sending to `escrow`, ensure the `from` address is an accesible acount in L2.
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
    virtual
    override(ERC721Upgradeable, IERC721Upgradeable)
  {
    bytes memory data;
    if (escrow != address(0) && to == escrow) {
      data = getTokenIdData(tokenId);
    }
    safeTransferFrom(from, to, tokenId, data);
  }

  /**
   *
   * @param spender of this allowance
   * @param tokenId to give allowance
   * @param deadline of the signature
   * @param v value of signature
   * @param r value of signature
   * @param s value of signature
   */
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
    override
  {
    require(_blockTimestamp() <= deadline, "Permit expired");

    bytes32 digest = getPermitDigest(spender, tokenId, _getAndIncrementNonce(tokenId), deadline);
    address owner = ownerOf(tokenId);

    require(spender != owner, "ERC721Permit: approval to current owner");

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

    _approve(spender, tokenId);
  }

  /**
   * @notice Common entry external function for the `permit()` function.
   *
   * @param params abi.encoded inputs for this.permit() public
   */
  function permit(bytes calldata params) external payable {
    (
      address unused1,
      address spender,
      uint256 tokenId,
      uint256 unused2,
      uint256 deadline,
      uint8 v,
      bytes32 r,
      bytes32 s
    ) = abi.decode(params, (address, address, uint256, uint256, uint256, uint8, bytes32, bytes32));
    {
      // push to stack to silence unused
      unused1;
      unused2;
    }
    permit(spender, tokenId, deadline, v, r, s);
  }

  function updateMarketData(
    uint256 tokenId,
    MgdL1MarketData calldata marketData,
    bool isL2Native
  )
    external
  {
    if (msg.sender != escrow) {
      revert MgdERC721PermitEscrowable__onlyEscrow_notAllowed();
    }
    if (isL2Native) {
      tokenIdArtist[tokenId] = marketData.artist;
      if (marketData.hasCollabs) {
        hasTokenCollaborators[tokenId] = marketData.hasCollabs;
        tokenIdCollaboratorsQuantity[tokenId] = marketData.collabsQuantity;
        tokenCollaborators[tokenId] = marketData.collabs;
        tokenIdCollaboratorsPercentage[tokenId] = marketData.collabsPercentage;
      }
    }
    tokenWasSold[tokenId] = marketData.tokenWasSold;
    primarySaleQuantityToSold[tokenId] = marketData.primarySaleQuantityToSell;

    emit EscrowUpdateMarketData(tokenId, marketData);
  }

  function getTokenIdData(uint256 tokenId) public view virtual returns (bytes memory data) {
    // TODO safe number casting
    data = abi.encode(
      MgdL1MarketData({
        artist: tokenIdArtist[tokenId],
        hasCollabs: hasTokenCollaborators[tokenId],
        tokenWasSold: tokenWasSold[tokenId],
        collabsQuantity: uint40(tokenIdCollaboratorsQuantity[tokenId]),
        primarySaleQuantityToSell: uint40(primarySaleQuantityToSold[tokenId]),
        royaltyPercent: uint128(tokenIdRoyaltyPercent[tokenId]),
        collabs: tokenCollaborators[tokenId],
        collabsPercentage: tokenIdCollaboratorsPercentage[tokenId]
      })
    );
  }

  function setEscrow(address escrow_) external isZeroAddress(escrow_) isowner {
    escrow = escrow_;
    emit SetEscrow(escrow_);
  }
}
