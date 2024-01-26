// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {CommonCheckers} from "../utils/CommonCheckers.sol";
import {ICrossDomainMessenger} from "../interfaces/ICrossDomainMessenger.sol";
import {L1VoucherData, MgdL1MarketData, TypeNFT} from "./VoucherDataTypes.sol";
import {MgdL2BaseNFT} from "./MgdL2BaseNFT.sol";
import {MgdL2NFTEscrow} from "../MgdL2NFTEscrow.sol";
import {MintGoldDustMarketplace} from "mgd-v2-contracts/marketplace/MintGoldDustMarketplace.sol";

abstract contract MgdL2BaseVoucher is MgdL2BaseNFT {
  ///Events
  event L1NftMintClearance(uint256 indexed voucherId, bool state);
  event L1NftMinted(uint256 indexed voucherId);

  event RedeemVoucher(
    uint256 indexed voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed releaseKey
  );

  event SetEscrow(address newEscrow);
  event SetMessenger(address newMessenger);
  event SetMgdERC721(address newMgdERC721);
  event SetMgdERC1155(address newMgdERC1155);

  /// Custom Errors
  error MgdL2BaseVoucher__onlyCrossAuthorized_notAllowed();
  error MgdL2BaseVoucher__mintL1Nft_notClearedOrAlreadyMinted();
  error MgdL2BaseVoucher__burnToken_notNative();
  error MgdL2BaseVoucher__burnToken_notAllowed();
  error MgdL2BaseVoucher__burnToken_cantBurnSoldVoucher();
  error MgdL2BaseVoucher__redeemVoucherToL1_notAllowed();
  error MgdL2BaseVoucher__redeemVoucherToL1_wrongReceiver();

  uint256 private constant _REF_NUMBER =
    0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

  // L1 reference addresses
  ICrossDomainMessenger public messenger;
  address public escrowL1;
  address public mgdNFTL1;

  // voucherId => bool isNative
  mapping(uint256 => bool) internal _natives;
  // voucherId => struct L1VoucherData
  mapping(uint256 => L1VoucherData) internal _voucherL1Data;

  /// @dev Mapping set from L1 to identify clearance to mint voucher.
  /// uint256 voucherId => bool cleared
  mapping(uint256 => bool) public mintCleared;

  /**
   * @dev This empty reserved space is put in place to allow future upgrades to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  modifier onlyCrossAuthorized() {
    if (msg.sender != address(messenger) && msg.sender != address(_mgdCompany)) {
      revert MgdL2BaseVoucher__onlyCrossAuthorized_notAllowed();
    }
    _;
  }

  /// @dev Initializes this contract
  /// @param mgdL2NFTescrow deployed on L1
  /// @param mgdL1NFTAddr represented by this voucher deployed on L1
  /// @param nftType type of NFT
  /// @param crossDomainMessenger canonical address communicating between L1 or L2
  function __MgdL2BaseVoucher_init(
    address mgdL2NFTescrow,
    address mgdL1NFTAddr,
    TypeNFT nftType,
    address crossDomainMessenger
  )
    internal
    onlyInitializing
  {
    _setMgdNFTL1(mgdL1NFTAddr, nftType);
    _setEscrow(mgdL2NFTescrow);
    _setMessenger(crossDomainMessenger);
  }

  function isVoucherNative(uint256 id) public view returns (bool) {
    return _natives[id];
  }

  function getVoucherL1Data(uint256 id) public view returns (L1VoucherData memory) {
    return _voucherL1Data[id];
  }

  ///@dev Called by authorized cross domain messenger to clear minting of voucherId.
  function setL1NftMintClearance(uint256 voucherId, bool state) external onlyCrossAuthorized {
    mintCleared[voucherId] = state;
    emit L1NftMintClearance(voucherId, state);
  }

  /// @notice Mint a voucher representing a L1 Nft. Calling this method requires minting clearance
  /// This is done by sending your NFT(s) to escrow in L1.
  /// @param tokenId in L1
  /// @param representedAmount of tokenId
  /// @param owner of tokenId in `nft` contract in L1
  /// @param blockHash when escrow tx occured
  /// @param marketData params when escrow occured
  function mintL1Nft(
    uint256 tokenId,
    uint256 representedAmount,
    address owner,
    bytes32 blockHash,
    MgdL1MarketData memory marketData
  )
    public
  {
    address nft = mgdNFTL1;
    uint256 voucherId =
      _generateL1EscrowedIdentifier(nft, tokenId, representedAmount, owner, blockHash, marketData);
    if (!mintCleared[voucherId]) {
      revert MgdL2BaseVoucher__mintL1Nft_notClearedOrAlreadyMinted();
    }

    delete mintCleared[voucherId];

    _executeMintFlow(owner, representedAmount, marketData, voucherId, "", bytes(""));

    _voucherL1Data[voucherId] =
      L1VoucherData({nft: nft, tokenId: tokenId, representedAmount: representedAmount});
  }

  /// @inheritdoc MgdL2BaseNFT
  function mintNft(
    string memory tokenURI,
    uint256 royalty,
    uint40 representedAmount,
    bytes memory memoir
  )
    public
    payable
    virtual
    override
    isArtistWhitelisted(msg.sender)
    whenNotPaused
    returns (uint256)
  {
    _checkRoyalty(royalty);
    CommonCheckers.checkGtZero(representedAmount);

    MgdL1MarketData memory marketData = MgdL1MarketData({
      artist: msg.sender,
      hasCollabs: false,
      tokenWasSold: false,
      collabsQuantity: 0,
      primarySaleL2QuantityToSell: representedAmount,
      royaltyPercent: royalty,
      collabs: [address(0), address(0), address(0), address(0)],
      collabsPercentage: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]
    });

    uint256 voucherId =
      _executeMintFlow(msg.sender, representedAmount, marketData, 0, tokenURI, memoir);
    _natives[voucherId] = true;
    _voucherL1Data[voucherId] =
      L1VoucherData({nft: mgdNFTL1, tokenId: _REF_NUMBER, representedAmount: representedAmount});
    return voucherId;
  }

  /// @inheritdoc MgdL2BaseNFT
  function splitMint(
    string memory tokenURI,
    uint128 royalty,
    address[] memory collaborators,
    uint256[] memory collabsPercentage,
    uint40 amount,
    bytes memory memoir
  )
    public
    virtual
    override
    whenNotPaused
    returns (uint256)
  {
    if (collabsPercentage.length != collaborators.length + 1) {
      revert MgdL2Voucher__splitMint_invalidArray();
    }
    uint256 voucherId = mintNft(tokenURI, royalty, amount, memoir);
    _executeSplitMintFlow(voucherId, collaborators, collabsPercentage);
    _natives[voucherId] = true;
    return voucherId;
  }

  /// @notice Bridge back `voucherId` to Ethereum.
  /// This action will release the NFT from escrow on Ethereum or
  /// if `voucherId` is a L2 native it will bring the NFT into existente in Ethereum.
  /// @dev CAUTION! This process can take up to 7 days to complete due to L2 rollup-requirements.
  /// @dev CAUTION! Ensure the `receiver` address is an accesible acount in Ethereum
  /// @param voucherId to bridge
  /// @param amount of NFT to bridge
  /// @param receiver of the NFT on L1
  function _redeemVoucherToL1(uint256 voucherId, uint256 amount, address receiver) internal virtual;

  /// @notice Allows an approved address or token owner to burn a voucher natively created in L2.
  /// @param voucherId The unique identifier for the token.
  /// @param amount token to burn.
  /// @param from address of the owner of the token.
  /// @dev Requirements:
  /// - `voucherId` must had been created native in L2.
  /// - Caller must be the owner of `voucherId`, or an approved address for `tokenId`,
  ///   or the owner of the contract, or a validated MintGoldDust address.
  /// - The `voucherId` must not have been sold previously.
  /// - Must emit a `TokenBurned` event containing the tokenId, burn status, sender, and amount.
  function _burnNativeVoucher(uint256 voucherId, uint256 amount, address from) internal virtual;

  function _setEscrow(address newEscrow) internal {
    CommonCheckers.checkZeroAddress(newEscrow);
    escrowL1 = newEscrow;
    emit SetEscrow(newEscrow);
  }

  function _setMessenger(address newMessenger) internal {
    CommonCheckers.checkZeroAddress(newMessenger);
    messenger = ICrossDomainMessenger(newMessenger);
    emit SetMessenger(newMessenger);
  }

  function _setMgdNFTL1(address newMgdNFTL1, TypeNFT nftType) internal {
    CommonCheckers.checkZeroAddress(newMgdNFTL1);
    mgdNFTL1 = newMgdNFTL1;
    if (nftType == TypeNFT.ERC721) {
      emit SetMgdERC721(newMgdNFTL1);
    } else {
      emit SetMgdERC1155(newMgdNFTL1);
    }
  }

  function _sendRedeemNoticeToL1(uint256 key) internal {
    bytes memory message =
      abi.encodeWithSelector(MgdL2NFTEscrow.setRedeemClearanceKey.selector, key, true);
    messenger.sendMessage(escrowL1, message, 1000000);
  }

  function _generateL1EscrowedIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    bytes32 blockHash,
    MgdL1MarketData memory marketData
  )
    internal
    pure
    returns (uint256 identifier)
  {
    identifier = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, marketData)));
  }

  function _generateL2NativeIdentifier(MgdL1MarketData memory tokenData)
    internal
    view
    returns (uint256 identifier)
  {
    identifier = uint256(keccak256(abi.encode(blockhash(block.number), tokenData)));
  }

  function _generateL1RedeemKey(
    uint256 voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    MgdL1MarketData memory marketData
  )
    internal
    view
    returns (uint256 key, bytes32 blockHash)
  {
    blockHash = blockhash(block.number);
    key =
      uint256(keccak256(abi.encode(voucherId, nft, tokenId, amount, owner, blockHash, marketData)));
  }

  function _clearVoucherData(uint256 voucherId) internal {
    delete _voucherL1Data[voucherId];
    delete _voucherMarketData[voucherId];
    delete _tokenIdMemoir[voucherId];
    delete _natives[voucherId];
  }
}
