// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Almost721Upgradeable} from "./utils/Almost721Upgradeable.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {MgdL2NFT, MgdL1NFTData} from "./abstract/MgdL2NFT.sol";

/// @title MgdL2NFTVoucher
/// @notice This contract "Vouchers" are a representation of an NFT on ethereum mainnet.
/// @dev This contract is meant to be deployed on L2s.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdL2NFTVoucher is Almost721Upgradeable, MgdL2NFT {
  ///Events
  event MintClearance(uint256 indexed voucherId, bool state);
  event SetEscrow(address newEscrow);
  event SetMessenger(address newMessenger);

  /// Custom Errors
  error MgdL2NFTVoucher__onlyCrossAuthorized_notAllowed();
  error MgdL2NFTVoucher__mintFromL1Data_notCleared();

  /// @dev Mapping set from L1 to identify clearance to mint voucher.
  // uint256 voucherId => bool cleared
  mapping(uint256 => bool) public mintCleared;

  ICrossDomainMessenger public messenger;
  address public escrowL1;

  modifier onlyCrossAuthorized() {
    if (
      msg.sender != address(messenger) || messenger.xDomainMessageSender() != escrowL1
        || msg.sender != address(_mgdCompany)
    ) {
      revert MgdL2NFTVoucher__onlyCrossAuthorized_notAllowed();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @dev Initializes the contract by setting calling parent initializers and
  ///      setting `escrow` and `messenger`.
  /// @param mgdCompanyL2Sync deployed on L2
  /// @param mgdL2NFTescrow deployed on L1
  /// @param crossDomainMessenger deployed on L2
  function initialize(
    address mgdCompanyL2Sync,
    address mgdL2NFTescrow,
    address crossDomainMessenger
  )
    external
    initializer
  {
    __MgdL2NFT_init(mgdCompanyL2Sync);
    __ERC721_init("Mint Gold Dust L2 Voucher", "mgdV");
    _setEscrow(mgdL2NFTescrow);
    _setMessenger(crossDomainMessenger);
  }

  function setMintClearance(uint256 voucherId, bool state) external onlyCrossAuthorized {
    mintCleared[voucherId] = state;
    emit MintClearance(voucherId, state);
  }

  ///
  /// @param nft contract address in L1
  /// @param tokenId in L1
  /// @param amount of tokenId
  /// @param owner of tokenId in `nft` contract in L1
  /// @param blockHash when escrow occured
  /// @param tokenData params when escrow occured
  function mintFromL1Data(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    bytes32 blockHash,
    MgdL1NFTData memory tokenData
  )
    public
  {
    uint256 voucherId =
      _generateL1EscrowedIdentifier(nft, tokenId, amount, owner, blockHash, tokenData);
    if (!mintCleared[voucherId]) {
      revert MgdL2NFTVoucher__mintFromL1Data_notCleared();
    }
    _executeMintFlow(owner, tokenData, voucherId, "", bytes(""));
  }

  /**
   * @dev Wrapper of {ERC721.safeTransferFrom(...)} to allow call uniformity with other contracts.
   * @param from sender of the token.
   * @param to token destionation.
   * @param voucherId id of the token.
   */
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

  function _executeMintFlow(
    address owner,
    MgdL1NFTData memory tokenData,
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
      generatedL1VoucherId == 0 ? _generateL2NativeIdentifier(tokenData) : generatedL1VoucherId;
    _safeMint(owner, voucherId);

    _voucherData[voucherId] = tokenData;
    if (memoir.length > 0) {
      _tokenIdMemoir[voucherId] = memoir;
    }

    emit MintGoldDustNFTMinted(
      voucherId,
      tokenURI,
      owner,
      tokenData.royaltyPercent,
      tokenData.representedAmount,
      tokenData.representedAmount == 1,
      0,
      memoir
    );
    return voucherId;
  }

  function _setEscrow(address newEscrow) internal {
    _checkZeroAddress(newEscrow);
    escrowL1= newEscrow;
    emit SetEscrow(newEscrow);
  }

  function _setMessenger(address newMessenger) internal {
    _checkZeroAddress(newMessenger);
    messenger = ICrossDomainMessenger(newMessenger);
    emit SetMessenger(newMessenger);
  }

  function _generateL1EscrowedIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    bytes32 blockHash,
    MgdL1NFTData memory tokenData
  )
    internal
    pure
    returns (uint256 identifier)
  {
    identifier = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, tokenData)));
  }
}
