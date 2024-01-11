// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Almost721Upgradeable} from "./utils/Almost721Upgradeable.sol";
import {ERC721Permit, ECDSA} from "./abstract/ERC721Permit.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {MgdL2Voucher, MgdL1MarketData, L1VoucherData} from "./abstract/MgdL2Voucher.sol";
import {MgdL2NFTEscrow} from "./MgdL2NFTEscrow.sol";
import {
  MintGoldDustMarketplace,
  ManageSecondarySale
} from "mgd-v2-contracts/MintGoldDustMarketplace.sol";

/// @title MgdL2NFTVoucher
/// @notice This contract "Vouchers" are a representation of an NFT on ethereum mainnet.
/// @dev This contract is meant to be deployed on L2s.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdL2NFTVoucher is MgdL2Voucher, ERC721Permit, Almost721Upgradeable {
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

  /// Custom Errors
  error MgdL2NFTVoucher__onlyCrossAuthorized_notAllowed();
  error MgdL2NFTVoucher__mintL1Nft_notClearedOrAlreadyMinted();
  error MgdL2NFTVoucher__burnToken_notNative();
  error MgdL2NFTVoucher__burnToken_notAllowed();
  error MgdL2NFTVoucher__burnToken_cantBurnSoldVoucher();
  error MgdL2NFTVoucher__redeemVoucherToL1_notAllowed();
  error MgdL2NFTVoucher__redeemVoucherToL1_wrongReceiver();

  /// @dev Mapping set from L1 to identify clearance to mint voucher.
  /// uint256 voucherId => bool cleared
  mapping(uint256 => bool) public mintCleared;

  ICrossDomainMessenger public messenger;

  /**
   * @dev This empty reserved space is put in place to allow future upgrades to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  modifier onlyCrossAuthorized() {
    if (msg.sender != address(messenger) && msg.sender != address(_mgdCompany)) {
      revert MgdL2NFTVoucher__onlyCrossAuthorized_notAllowed();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @dev Initializes the contract
  /// @param mgdCompanyL2Sync deployed on L2
  /// @param mgdL2NFTescrow deployed on L1
  /// @param mgdERC721 deployed on L1
  /// @param mgdERC1155 deployed on L1
  /// @param crossDomainMessenger canonical address communicating between L1 or L2
  function initialize(
    address mgdCompanyL2Sync,
    address mgdL2NFTescrow,
    address mgdERC721,
    address mgdERC1155,
    address crossDomainMessenger
  )
    external
    initializer
  {
    __MgdL2NFT_init(mgdCompanyL2Sync, mgdERC721, mgdERC1155);
    __ERC721_init("Mint Gold Dust L2 Voucher", "mgdV");
    _setEscrow(mgdL2NFTescrow);
    _setMessenger(crossDomainMessenger);
  }

  ///@dev Called by authorized cross domain messenger to clear minting of voucherId.
  function setL1NftMintClearance(uint256 voucherId, bool state) external onlyCrossAuthorized {
    mintCleared[voucherId] = state;
    emit L1NftMintClearance(voucherId, state);
  }

  /// @notice Mint a voucher representing a L1 Nft. Calling this method requires minting clearance
  /// This is done by sending your NFT(s) to escrow in L1.
  /// @param nft contract address in L1
  /// @param tokenId in L1
  /// @param representedAmount of tokenId
  /// @param owner of tokenId in `nft` contract in L1
  /// @param blockHash when escrow tx occured
  /// @param marketData params when escrow occured
  function mintL1Nft(
    address nft,
    uint256 tokenId,
    uint256 representedAmount,
    address owner,
    bytes32 blockHash,
    MgdL1MarketData memory marketData
  )
    public
  {
    uint256 voucherId =
      _generateL1EscrowedIdentifier(nft, tokenId, representedAmount, owner, blockHash, marketData);
    if (!mintCleared[voucherId]) {
      revert MgdL2NFTVoucher__mintL1Nft_notClearedOrAlreadyMinted();
    }

    delete mintCleared[voucherId];

    _executeMintFlow(owner, representedAmount, marketData, voucherId, "", bytes(""));
    if (marketData.mgdMarketPlaceData.length > 0) {
      // TODO
    }
    _voucherL1Data[voucherId] =
      L1VoucherData({nft: nft, tokenId: tokenId, representedAmount: representedAmount});
  }

  /// @notice Bridge back `voucherId` to Ethereum.
  /// This action will release the NFT from escrow on Ethereum or
  /// if `voucherId` is a L2 native it will bring the NFT into existente in Ethereum.
  /// @dev CAUTION! This process can take up to 7 days to complete due to L2 rollup-requirements.
  /// @dev CAUTION! Ensure the `receiver` address is an accesible acount in Ethereum
  /// @param voucherId to bridge
  /// @param receiver of the NFT on L1
  function redeemVoucherToL1(uint256 voucherId, address receiver) public {
    if (!_isApprovedOrOwner(msg.sender, voucherId)) {
      revert MgdL2NFTVoucher__redeemVoucherToL1_notAllowed();
    }
    if (receiver == escrowL1 || receiver == address(0)) {
      revert MgdL2NFTVoucher__redeemVoucherToL1_wrongReceiver();
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

    _burnVoucherAndClearData(voucherId);
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

  /// @notice Allows an approved address or token owner to burn a voucher natively created in L2.
  /// @param voucherId The unique identifier for the token.
  /// @dev Requirements:
  /// - `voucherId` must had been created native in L2.
  /// - Caller must be the owner of `voucherId`, or an approved address for `tokenId`,
  ///   or the owner of the contract, or a validated MintGoldDust address.
  /// - The `voucherId` must not have been sold previously.
  /// - Must emit a `TokenBurned` event containing the tokenId, burn status, sender, and amount.
  function burnNativeVoucher(uint256 voucherId) external whenNotPaused {
    if (!isVoucherNative(voucherId)) {
      revert MgdL2NFTVoucher__burnToken_notNative();
    }
    if (
      !_isApprovedOrOwner(msg.sender, voucherId) && msg.sender != _mgdCompany.owner()
        && !_mgdCompany.isAddressValidator(msg.sender)
    ) revert MgdL2NFTVoucher__burnToken_notAllowed();

    MgdL1MarketData memory voucherData = _voucherMarketData[voucherId];

    if (voucherData.tokenWasSold != false) {
      revert MgdL2NFTVoucher__burnToken_cantBurnSoldVoucher();
    }

    _burnVoucherAndClearData(voucherId);

    emit TokenBurned(voucherId, true, voucherData.artist, msg.sender, 1);
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

  function _setEscrow(address newEscrow) internal {
    _checkZeroAddress(newEscrow);
    escrowL1 = newEscrow;
    emit SetEscrow(newEscrow);
  }

  function _setMessenger(address newMessenger) internal {
    _checkZeroAddress(newMessenger);
    messenger = ICrossDomainMessenger(newMessenger);
    emit SetMessenger(newMessenger);
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

  function _burnVoucherAndClearData(uint256 voucherId) internal {
    _burn(voucherId);
    delete _voucherL1Data[voucherId];
    delete _voucherMarketData[voucherId];
    delete _tokenIdMemoir[voucherId];
    delete _natives[voucherId];
  }
}
