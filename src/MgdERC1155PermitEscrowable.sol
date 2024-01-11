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
import {
  MintGoldDustMarketplace,
  ManageSecondarySale
} from "mgd-v2-contracts/MintGoldDustMarketplace.sol";
import {MgdL1MarketData} from "./abstract/MgdL2Voucher.sol";

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
  event SetEscrow(address escrow_);

  /**
   * @dev Emit when `escrow` address is set.
   */
  event EscrowUpdateMarketData(uint256 indexed tokenId, MgdL1MarketData marketData);

  /// Custom Errors
  error MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();

  address public escrow;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Overriden to utilize the allowance in {ERC1155Allowance} set up in this contract.
  /// @dev CAUTION! If sending to `escrow`, ensure the `from` address is an accesible acount in L2.
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
      from == operator || allowance(from, operator, id) >= amount,
      "ERC1155: caller is not owner or approved or has allowance"
    );
    if (from != operator && !isApprovedForAll(from, operator)) {
      _spendAllowance(from, operator, id, amount);
    }
    if (escrow != address(0) && to == escrow) {
      data = getTokenIdData(id, _safeCastToUint40(amount));
    }
    _safeTransferFrom(from, to, id, amount, data);
  }

  /// @inheritdoc ERC1155Allowance
  function allowance(
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

  function updateMarketData(
    uint256 tokenId,
    MgdL1MarketData calldata marketData,
    bool isL2Native
  )
    external
  {
    if (msg.sender != escrow) {
      revert MgdERC1155PermitEscrowable__onlyEscrow_notAllowed();
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
    primarySaleQuantityToSold[tokenId] += marketData.primarySaleQuantityToSell;

    emit EscrowUpdateMarketData(tokenId, marketData);
  }

  function setEscrow(address escrow_) external isZeroAddress(escrow_) isowner {
    escrow = escrow_;
    emit SetEscrow(escrow_);
  }

  /**
   * @notice Returns the data to escow for a given `tokenId` and `amountToEscrow`.
   * @param tokenId to get market data
   * @param amountToEscrow being sent
   */
  function getTokenIdData(
    uint256 tokenId,
    uint40 amountToEscrow
  )
    public
    view
    virtual
    returns (bytes memory data)
  {
    uint40 primarySaleRemaining = _safeCastToUint40(primarySaleQuantityToSold[tokenId]);
    uint40 primarySaleToCarry = primarySaleRemaining > amountToEscrow
      ? primarySaleRemaining - amountToEscrow
      : primarySaleRemaining;
    ManageSecondarySale memory msSale =
      MintGoldDustMarketplace(mintGoldDustSetPriceAddress).getSecondarySale(address(this), tokenId);

    data = abi.encode(
      MgdL1MarketData({
        artist: tokenIdArtist[tokenId],
        hasCollabs: hasTokenCollaborators[tokenId],
        tokenWasSold: tokenWasSold[tokenId],
        collabsQuantity: _safeCastToUint40(tokenIdCollaboratorsQuantity[tokenId]),
        primarySaleQuantityToSell: primarySaleToCarry,
        royaltyPercent: _safeCastToUint128(tokenIdRoyaltyPercent[tokenId]),
        collabs: tokenCollaborators[tokenId],
        collabsPercentage: tokenIdCollaboratorsPercentage[tokenId],
        mgdMarketPlaceData: abi.encode(msSale)
      })
    );
  }

  function _safeCastToUint40(uint256 value) internal pure returns (uint40) {
    require(value <= type(uint40).max, "Value exceeds uint40");
    return uint40(value);
  }

  function _safeCastToUint128(uint256 value) internal pure returns (uint128) {
    require(value <= type(uint128).max, "Value exceeds uint128");
    return uint128(value);
  }
}
