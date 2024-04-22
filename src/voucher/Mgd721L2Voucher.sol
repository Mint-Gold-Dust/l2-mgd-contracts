// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Almost721Upgradeable} from "../utils/Almost721Upgradeable.sol";
import {ECDSA, ERC721Permit} from "../abstract/ERC721Permit.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {L1VoucherData, MgdL1MarketData, TypeNFT} from "./VoucherDataTypes.sol";
import {MgdL2BaseVoucher} from "./MgdL2BaseVoucher.sol";

/// @title Mgd721L2Voucher
/// @notice This contract "Vouchers" are a representation of a 721 NFT on ethereum mainnet.
/// @dev This contract is meant to be deployed on L2s.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract Mgd721L2Voucher is MgdL2BaseVoucher, ERC721Permit, Almost721Upgradeable {
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
  /// @param mgdERC721 deployed on L1
  /// @param crossDomainMessenger canonical address communicating between L1 or L2
  function initialize(
    address mgdCompanyL2Sync,
    address mgdL2NFTescrow,
    address mgdERC721,
    address crossDomainMessenger
  )
    external
    initializer
  {
    __ERC721_init("Mint Gold Dust L2 Voucher", "mgdV");
    __MgdL2BaseNFT_init(mgdCompanyL2Sync);
    __MgdL2BaseVoucher_init(mgdL2NFTescrow, mgdERC721, TypeNFT.ERC721, crossDomainMessenger);
  }

  /// @inheritdoc ERC721Permit
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

  /// @dev Wrapper of {ERC721.safeTransferFrom(...)} to allow call uniformity with other contracts.
  /// @param from sender of the token
  /// @param to token destination
  /// @param voucherId id of the token
  function transfer(
    address from,
    address to,
    uint256 voucherId,
    uint256 /*amount*/
  )
    public
    virtual
    override
    nonReentrant
  {
    safeTransferFrom(from, to, voucherId, "");
  }

  /// @inheritdoc MgdL2BaseVoucher
  function mintVoucherFromL1Nft(
    uint256 tokenId,
    uint256, /*representedAmount*/
    address owner,
    bytes32 blockHash,
    MgdL1MarketData memory marketData
  )
    public
    override
  {
    return super.mintVoucherFromL1Nft(tokenId, 1, owner, blockHash, marketData);
  }

  /// @inheritdoc MgdL2BaseVoucher
  function mintNft(
    string memory tokenURI,
    uint256 royalty,
    uint40, /* representedAmount */
    bytes memory memoir
  )
    public
    payable
    override
    isArtistWhitelisted(msg.sender)
    whenNotPaused
    returns (uint256)
  {
    return super.mintNft(tokenURI, royalty, 1, memoir);
  }

  /// @notice Refer to {MgdL2BaseVoucher-_redeeemVoucherToL1()}
  function redeemVoucherToL1(uint256 voucherId, address receiver) public returns (uint256) {
    return _redeemVoucherToL1(msg.sender, voucherId, 1, receiver);
  }

  /// @inheritdoc MgdL2BaseVoucher
  function _redeemVoucherToL1(
    address,
    uint256 voucherId,
    uint40,
    address receiver
  )
    internal
    override
    returns (uint256)
  {
    RedeemVoucherData memory redeemData;
    redeemData.voucherId = voucherId;
    redeemData.amount = 1;
    redeemData.receiver = receiver;

    if (!_isApprovedOrOwner(msg.sender, voucherId)) {
      revert MgdL2BaseVoucher__redeemVoucherToL1_notAllowed();
    }
    if (receiver == escrowL1 || receiver == address(0)) {
      revert MgdL2BaseVoucher__redeemVoucherToL1_wrongReceiver();
    }
    L1VoucherData memory voucherData = _voucherL1Data[voucherId];
    MgdL1MarketData memory marketData = _voucherMarketData[voucherId];

    (redeemData.releaseKey, redeemData.blockHash) = _generateL1ReleaseKey(
      voucherId, voucherData.nft, voucherData.tokenId, redeemData.amount, receiver, marketData
    );
    _emitRedeemVoucher(redeemData, marketData);
    _burnVoucherAndClearData(voucherId);
    _sendRedeemNoticeToL1(redeemData.releaseKey);

    return redeemData.releaseKey;
  }

  /// @notice See {MgdL2BaseVolcher-burnNativeVoucher}
  function burnNativeVoucher(uint256 voucherId) external whenNotPaused {
    _burnNativeVoucher(voucherId, 1, address(1));
  }

  /// @inheritdoc MgdL2BaseVoucher
  function _burnNativeVoucher(uint256 voucherId, uint256, address) internal override {
    if (!isVoucherNative(voucherId)) {
      revert MgdL2BaseVoucher__burnToken_notNative();
    }
    if (
      !_isApprovedOrOwner(msg.sender, voucherId) && msg.sender != _mgdCompany.owner()
        && !_mgdCompany.isAddressValidator(msg.sender)
    ) revert MgdL2BaseVoucher__burnToken_notAllowed();

    MgdL1MarketData memory voucherData = _voucherMarketData[voucherId];

    if (voucherData.tokenWasSold != false) {
      revert MgdL2BaseVoucher__burnToken_cantBurnSoldVoucher();
    }

    _burnVoucherAndClearData(voucherId);

    emit TokenBurned(voucherId, true, voucherData.artist, msg.sender, 1);
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
    _safeMint(owner, voucherId);

    _voucherMarketData[voucherId] = marketData;

    if (generatedL1VoucherId == 0) {
      _tokenURIs[voucherId] = tokenURI;
      if (memoir.length > 0) {
        _tokenIdMemoir[voucherId] = memoir;
      }
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

  function _burnVoucherAndClearData(uint256 voucherId) internal {
    _burn(voucherId);
    _clearVoucherData(voucherId);
  }
}
