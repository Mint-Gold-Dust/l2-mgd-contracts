// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Almost1155Upgradeable} from "./utils/Almost1155Upgradeable.sol";
import {MgdCompanyL2Sync} from "./MgdCompanyL2Sync.sol";

struct VoucherData {
  address nft;
  uint256 tokenId;
  uint256 amount;
}

/// @title MgdL2NFTVoucher
/// @notice This contract "Vouchers" are a representation of an NFT on ethereum mainnet.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdL2NFTVoucher is Almost1155Upgradeable {
  /// Custom Errors
  error MgdL2NFTVoucher__onlyCrossMessenger_error();
  error MgdL2NFTVoucher_isArtistWhitelisted_unauthorized();

  MgdCompanyL2Sync internal _mgdCompany;

  // voucherId => bool
  mapping(bytes32 => bool) public isEscrowedConfirmed;
  // voucherId => VoucherData
  mapping(bytes32 => VoucherData) public voucherData;

  modifier onlyCrossMessenger() {
    address messenger = address(_mgdCompany.crossDomainMessenger());
    if (messenger == address(0) || msg.sender != messenger) {
      revert MgdL2NFTVoucher__onlyCrossMessenger_error();
    }
    _;
  }

  /// @notice Check if the address is whitelisted
  modifier isArtistWhitelisted(address artist) {
        if (!_mgdCompany.isArtistApproved(artist)) {
            revert MgdL2NFTVoucher_isArtistWhitelisted_unauthorized();
        }
        _;
    }

  function initialize(address mgdCompany) external initializer isZeroAddress(mgdCompany) {
    _mgdCompany = MgdCompanyL2Sync(mgdCompany);
  }

  function setEscrowedConfirmed(
    address nft,
    uint256 tokenId,
    uint256 amount,
    bytes32 voucherId
  )
    onlyCrossMessenger
  {}

  /**
   * @notice Use this method to mint a L2 representation of an MGD Nft
   * 
   * @param nft 
   * @param tokenId 
   * @param amount 
   * @param voucherId 
   */
  function mintOptimisticVoucher(
    address nft,
    uint256 tokenId,
    uint256 amount,
    bytes32 voucherId
  )
    external
    onlyWhitelisted
  {}

  function mintL2NativeNftVoucher(
        string calldata _tokenURI,
        uint256 _royaltyPercent,
        uint256 _amount,
        bytes calldata _memoir
    )
        public
        payable
        isArtistWhitelisted(msg.sender)
        validPercentage(_royaltyPercent)
        whenNotPaused
        returns (uint256)
    {
        uint256 newTokenId = executeMintFlow(
            _tokenURI,
            _royaltyPercent,
            _amount,
            msg.sender,
            0,
            _memoir
        );

        return newTokenId;
    }
}
