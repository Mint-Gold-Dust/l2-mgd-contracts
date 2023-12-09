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
// /// Custom Errors
// error MgdL2NFTVoucher__onlyCrossMessenger_error();
// error MgdL2NFTVoucher_isArtistWhitelisted_unauthorized();

// /**
//  * @dev Emit when minting or split minting.
//  * @param tokenId the uint256 generated for this token.
//  * @param tokenURI the URI that contains the metadata for the NFT.
//  * @param owner the address of the artist creator.
//  * @param royalty the royalty percetage choosen by the artist for this token.
//  * @param amount the quantity to be minted for this token.
//  * @param isERC721 a boolean that indicates if this token is ERC721 or ERC1155.
//  * @param collectorMintId a unique identifier for the collector mint.
//  * @param memoir the memoir for this token.
//  */
// event MintGoldDustNFTMinted(
//   uint256 indexed tokenId,
//   string tokenURI,
//   address owner,
//   uint256 royalty,
//   uint256 amount,
//   bool isERC721,
//   uint256 collectorMintId,
//   bytes memoir
// );

// MgdCompanyL2Sync private _mgdCompany;
// address private _mintGoldDustSetPriceAddress;
// address private _mintGoldDustMarketplaceAuctionAddress;
// mapping(uint256 => bool) internal _tokenWasSold;
// mapping(uint256 => uint256) internal _primarySaleQuantityToSold;

// mapping(uint256 => address) public tokenIdArtist;
// mapping(uint256 => uint256) public tokenIdRoyaltyPercent;
// mapping(uint256 => bytes) public tokenIdMemoir;
// mapping(uint256 => address[4]) public tokenCollaborators;
// mapping(uint256 => uint256[5]) public tokenIdCollaboratorsPercentage;
// mapping(uint256 => bool) public hasTokenCollaborators;
// mapping(uint256 => uint256) public tokenIdCollaboratorsQuantity;

// // voucherId => bool
// mapping(bytes32 => bool) public isEscrowedConfirmed;
// // voucherId => VoucherData
// mapping(bytes32 => VoucherData) public voucherData;

// /**
//  * @dev This empty reserved space is put in place to allow future versions to add new
//  * variables without shifting down storage in the inheritance chain.
//  * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
//  */
// uint256[50] private __gap;

// modifier onlyCrossMessenger() {
//   address messenger = address(_mgdCompany.crossDomainMessenger());
//   if (messenger == address(0) || msg.sender != messenger) {
//     revert MgdL2NFTVoucher__onlyCrossMessenger_error();
//   }
//   _;
// }

// /// @notice Check if the address is whitelisted
// modifier isArtistWhitelisted(address artist) {
//   if (!_mgdCompany.isArtistApproved(artist)) {
//     revert MgdL2NFTVoucher_isArtistWhitelisted_unauthorized();
//   }
//   _;
// }

// function initialize(address mgdCompany) external initializer {
//   _checkZeroAddress(mgdCompany);
//   _mgdCompany = MgdCompanyL2Sync(mgdCompany);
// }

// /**
//  * @notice Use this method to mint a L2 representation of an MGD Nft
//  *
//  * @param nft
//  * @param tokenId
//  * @param amount
//  * @param voucherId
//  */
// function mintVoucher(
//   address nft,
//   uint256 tokenId,
//   uint256 amount,
//   bytes32 voucherId,
//   bytes memory escrowableSignature
// )
//   external
//   onlyWhitelisted
// {}

// function mintSplitVoucher(
//   string calldata _tokenURI,
//   uint256 _royaltyPercent,
//   uint256 _amount,
//   bytes calldata _memoir
// )
//   public
//   payable
//   isArtistWhitelisted(msg.sender)
//   validPercentage(_royaltyPercent)
//   whenNotPaused
//   returns (uint256)
// {
//   uint256 newTokenId =
//     executeMintFlow(_tokenURI, _royaltyPercent, _amount, msg.sender, 0, _memoir);

//   return newTokenId;
// }

// function setEscrowedConfirmed(
//   address nft,
//   uint256 tokenId,
//   uint256 amount,
//   bytes32 voucherId
// )
//   onlyCrossMessenger
// {}

// function _executeSplitMintFlow(
//   uint256 tokenId,
//   address[] calldata collabs,
//   uint256[] calldata collabsPercentage
// )
//   private
// {
//   uint256 collabsCount = 0;
//   /// @dev it is a new variable to keep track of the total percentage assigned to collaborators.
//   uint256 totalPercentage = 0;

//   for (uint256 i = 0; i < collabs.length; i++) {
//     _checkZeroAddress(collabs[i]);
//     _checkGtZero(collabsPercentage[i]);

//     collabsCount++;
//     totalPercentage += collabsPercentage[i];
//     /// @dev Accumulate the percentage for each valid collaborator
//     tokenCollaborators[tokenId][i] = collabs[i];
//     tokenIdCollaboratorsPercentage[tokenId][i] = collabsPercentage[i];
//   }

//   _checkGtZero(collabsPercentage[collabsCount]);

//   require(ownersCount >= 1, "Add more than 1 owner!");

//   require(ownersCount < 5, "Add max 4!");

//   /// @dev the array of percentages is always one number greater than the collaborators length.
//   /// So is necessary do one more addition here.
//   totalPercentage += _ownersPercentage[ownersCount];

//   if (totalPercentage != 100e18) {
//     revert TheTotalPercentageCantBeGreaterOrLessThan100();
//   }

//   tokenIdCollaboratorsQuantity[_tokenId] = ownersCount + 1;
//   tokenIdCollaboratorsPercentage[_tokenId][ownersCount] = _ownersPercentage[ownersCount];

//   hasTokenCollaborators[_tokenId] = true;
//   emit MintGoldDustNftMintedAndSplitted(_tokenId, _newOwners, _ownersPercentage, address(this));
// }
}
