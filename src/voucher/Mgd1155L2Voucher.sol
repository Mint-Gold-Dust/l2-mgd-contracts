// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Almost1155Upgradeable} from "../utils/Almost1155Upgradeable.sol";
import {ECDSA, ERC1155Allowance, ERC1155Permit} from "../abstract/ERC1155Permit.sol";
import {ICrossDomainMessenger} from "../interfaces/ICrossDomainMessenger.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {L1VoucherData, MgdL1MarketData, TypeNFT} from "./VoucherDataTypes.sol";
import {MgdL2BaseVoucher} from "./MgdL2BaseVoucher.sol";
import {MgdL2NFTEscrow} from "../MgdL2NFTEscrow.sol";
import {MintGoldDustMarketplace} from "mgd-v2-contracts/marketplace/MintGoldDustMarketplace.sol";

/// @title Mgd1155L2Voucher
/// @notice This contract "Vouchers" are a representation of a 1155 NFT on ethereum mainnet.
/// @dev This contract is meant to be deployed on L2s.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract Mgd1155L2Voucher is MgdL2BaseVoucher, ERC1155Permit, Almost1155Upgradeable {
  /**
   * @dev This empty reserved space is put in place to allow future upgrades to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @dev Initializes the contract
  /// @param mgdCompanyL2Sync deployed on L2
  /// @param mgdL2NFTescrow deployed on L1
  /// @param mgdERC1155 deployed on L1
  /// @param crossDomainMessenger canonical address communicating between L1 or L2
  function initialize(
    address mgdCompanyL2Sync,
    address mgdL2NFTescrow,
    address mgdERC1155,
    address crossDomainMessenger
  )
    external
    initializer
  {
    __MgdL2BaseNFT_init(mgdCompanyL2Sync);
    __MgdL2BaseVoucher_init(mgdL2NFTescrow, mgdERC1155, TypeNFT.ERC1155, crossDomainMessenger);
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

  /// @dev Wrapper of {ERC721.safeTransferFrom(...)} to allow call uniformity with other contracts.
  /// @param from sender of the token
  /// @param to token destination
  /// @param voucherId id of the token
  /// @param amount tokens to be transferred
  function transfer(
    address from,
    address to,
    uint256 voucherId,
    uint256 amount
  )
    public
    virtual
    override
    nonReentrant
  {
    safeTransferFrom(from, to, voucherId, amount, "");
  }

  /// @notice Refer to {MgdL2BaseVoucher-_redeeemVoucherToL1()}
  function redeemVoucherToL1(
    uint256 voucherId,
    uint256 amount,
    address receiver
  )
    public
    returns (uint256)
  {
    return _redeemVoucherToL1(voucherId, amount, receiver);
  }

  /// @inheritdoc MgdL2BaseVoucher
  function _redeemVoucherToL1(
    uint256 voucherId,
    uint256 amount,
    address receiver
  )
    internal
    override
    returns (uint256)
  {
    if (balanceOf(msg.sender, voucherId) < amount) {
      revert MgdL2BaseVoucher__redeemVoucherToL1_notAllowed();
    }
    if (receiver == escrowL1 || receiver == address(0)) {
      revert MgdL2BaseVoucher__redeemVoucherToL1_wrongReceiver();
    }
    L1VoucherData memory voucherData = _voucherL1Data[voucherId];
    MgdL1MarketData memory marketData = _voucherMarketData[voucherId];

    (uint256 releaseKey, bytes32 blockHash) = _generateL1RedeemKey(
      voucherId,
      voucherData.nft,
      voucherData.tokenId,
      voucherData.representedAmount,
      receiver,
      marketData
    );

    _burnVoucherAndClearData(voucherId, amount, msg.sender);
    _sendRedeemNoticeToL1(releaseKey);

    emit RedeemVoucher(
      voucherId,
      voucherData.nft,
      voucherData.tokenId,
      voucherData.representedAmount,
      receiver,
      blockHash,
      marketData,
      releaseKey
    );

    return releaseKey;
  }

  /// @notice See {MgdL2BaseVoucher-_burnNativeVoucher()}
  function burnNativeVoucher(
    uint256 voucherId,
    uint256 amount,
    address from
  )
    external
    whenNotPaused
  {
    _burnNativeVoucher(voucherId, amount, from);
  }

  /// @inheritdoc MgdL2BaseVoucher
  function _burnNativeVoucher(uint256 voucherId, uint256 amount, address from) internal override {
    if (!isVoucherNative(voucherId)) {
      revert MgdL2BaseVoucher__burnToken_notNative();
    }

    if (
      msg.sender != from && msg.sender != _mgdCompany.owner()
        && !_mgdCompany.isAddressValidator(msg.sender)
    ) revert MgdL2BaseVoucher__burnToken_notAllowed();

    MgdL1MarketData memory voucherData = _voucherMarketData[voucherId];

    if (voucherData.tokenWasSold != false) {
      revert MgdL2BaseVoucher__burnToken_cantBurnSoldVoucher();
    }

    _burnVoucherAndClearData(voucherId, amount, from);

    emit TokenBurned(voucherId, true, voucherData.artist, msg.sender, amount);
  }

  function _executeMintFlow(
    address owner,
    uint256 representedAmount,
    MgdL1MarketData memory marketData,
    uint256 generatedL1VoucherId,
    string memory tokenURI,
    bytes memory memoir
  )
    internal
    virtual
    override
    returns (uint256 voucherId)
  {
    voucherId =
      generatedL1VoucherId == 0 ? _generateL2NativeIdentifier(marketData) : generatedL1VoucherId;
    _mint(owner, voucherId, representedAmount, "");

    _voucherMarketData[voucherId] = marketData;
    if (memoir.length > 0) {
      _tokenIdMemoir[voucherId] = memoir;
    }

    if (generatedL1VoucherId == 0) {
      emit MintGoldDustNFTMinted(
        voucherId,
        tokenURI,
        owner,
        marketData.royaltyPercent,
        representedAmount,
        representedAmount == 1,
        0,
        memoir
      );
    } else {
      emit L1NftMinted(voucherId);
    }
    return voucherId;
  }

  function _burnVoucherAndClearData(uint256 voucherId, uint256 amount, address from) internal {
    _burn(from, voucherId, amount);
    _clearVoucherData(voucherId);
  }
}
