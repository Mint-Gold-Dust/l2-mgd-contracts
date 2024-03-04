// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {CommonCheckers} from "../utils/CommonCheckers.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
  "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {MgdCompanyL2Sync} from "./../MgdCompanyL2Sync.sol";
import {MgdL1MarketData, L1VoucherData, TypeNFT} from "./VoucherDataTypes.sol";
import {ManagePrimarySale} from "mgd-v2-contracts/libraries/MgdMarketPlaceDataTypes.sol";

abstract contract MgdL2BaseNFT is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  /// Events

  /// @dev Emit when minting.
  event MintGoldDustNFTMinted(
    uint256 indexed voucherId,
    string tokenURI,
    address owner,
    uint256 royalty,
    uint256 amount,
    bool isERC721,
    uint256 collectorMintId,
    bytes memoir
  );
  /// @dev Emit split minting.
  event MintGoldDustNftMintedAndSplitted(
    uint256 indexed voucherId,
    address[] collaborators,
    uint256[] ownersPercentage,
    address contractAddress
  );
  /// @dev Emit when burning.
  event TokenBurned(
    uint256 indexed voucherId, bool isERC721, address owner, address burner, uint256 amount
  );

  /// Custom Errors
  error MgdL2Voucher__executeSplitMintFlow_failedPercentSumCheck();
  error MgdL2Voucher__notAuthorized(string restriction);
  error MgdL2Voucher__checkRoyalty_moreThanMax();
  error MgdL2Voucher__splitMint_invalidArray();
  error MgdL2Voucher__collectorMint_disabledInL2();

  MgdCompanyL2Sync internal _mgdCompany;
  address internal _mintGoldDustSetPrice;
  address internal _mintGoldDustMarketplaceAuction;

  // voucherId => struct MgdL1MarketData
  mapping(uint256 => MgdL1MarketData) internal _voucherMarketData;
  mapping(uint256 => string) internal _tokenURIs;
  mapping(uint256 => bytes) internal _tokenIdMemoir;

  /**
   * @dev This empty reserved space is put in place to allow future upgrades to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Revert if caller is the {mgdCompany.owner()}
  modifier isOwner() {
    if (msg.sender != _mgdCompany.owner()) {
      revert MgdL2Voucher__notAuthorized("owner");
    }
    _;
  }

  /// @dev Revert if caller is not a whitelisted artist
  modifier isArtistWhitelisted(address _artistAddress) {
    if (!_mgdCompany.isArtistApproved(_artistAddress)) {
      revert MgdL2Voucher__notAuthorized("artist");
    }
    _;
  }

  /// @dev Initializes this contract
  function __MgdL2BaseNFT_init(address mgdCompanyL2Sync) internal onlyInitializing {
    CommonCheckers.checkZeroAddress(mgdCompanyL2Sync);
    _mgdCompany = MgdCompanyL2Sync(payable(mgdCompanyL2Sync));
    __ReentrancyGuard_init();
    __Pausable_init();
  }

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external virtual;

  function getVoucherMarketData(uint256 id) public view returns (MgdL1MarketData memory) {
    return _voucherMarketData[id];
  }

  function tokenIdMemoir(uint256 id) public view returns (bytes memory) {
    return _tokenIdMemoir[id];
  }

  function getManagePrimarySale(uint256 _tokenId) public view returns (ManagePrimarySale memory) {
    uint256 remaining = _voucherMarketData[_tokenId].primarySaleL2QuantityToSell;
    return ManagePrimarySale({
      owner: _voucherMarketData[_tokenId].artist,
      soldout: remaining == 0,
      amount: remaining
    });
  }

  /// @notice Mint a native voucher that represents a new MintGoldDustNFT token in a L2.
  /// @param tokenURI the URI that contains the metadata for the NFT.
  /// @param royalty percentage to be applied for this NFT secondary sales.
  /// @param representedAmount editions adjoined to this voucher.
  /// @param memoir for this mint
  /// @dev Requirements:
  /// - Only whitelisted artists can mint.
  /// - `royalty` percentage must be less than or equal to the max royalty percentage.
  /// - `representedAmount` must be greater than zero.
  /// - 721 voucher contract can only pass `representedAmount` equals 1.
  function mintNft(
    string memory tokenURI,
    uint256 royalty,
    uint40 representedAmount,
    bytes memory memoir
  )
    public
    payable
    virtual
    returns (uint256);

  /// @notice Mint a native voucher with collaborators that represents a new MintGoldDustNFT token in a L2.
  /// @dev Percentages in `collabsPercentage` must match the position of `collaborators` array.
  /// @dev The last and additional `collabsPercentage` position must correspond to the `artist`.
  /// @param tokenURI the URI that contains the metadata for the NFT.
  /// @param royalty the royalty percentage to be applied for this NFT secondary sales.
  /// @param collaborators an array of address that can be a number of maximum 4 collaborators.
  /// @param collabsPercentage an array of uint256 that are the percetages for the artist and for each one of the collaborators.
  /// @param amount the quantity to be minted for this token.
  /// @param memoir for this mint
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
    returns (uint256);

  /// @notice Collector mint is disabled in MGD L2 contracts.
  /// @dev  Kept this function to throw error message when called
  /// by other MGD v2-core unchanged contracts.
  function collectorMint(
    string memory,
    uint256,
    uint256,
    address,
    bytes memory,
    uint256,
    address
  )
    external
    pure
    returns (uint256)
  {
    revert MgdL2Voucher__collectorMint_disabledInL2();
  }

  /// @notice Collector split mint is disabled in MGD L2 contracts.
  /// @dev  Kept this function to throw error message when called
  /// by other MGD v2-core unchanged contracts.
  function collectorSplitMint(
    string memory,
    uint256,
    address[] memory,
    uint256[] memory,
    uint256,
    address,
    bytes memory,
    uint256,
    address
  )
    external
    pure
    returns (uint256)
  {
    revert MgdL2Voucher__collectorMint_disabledInL2();
  }

  /// @notice Reduces the quantity of remaining items available for primary sale for a specific token.
  ///         Only executes the update if there is a non-zero quantity of the token remaining for primary sale.
  /// @dev This function must only be called by authorized marketplace related addresses.
  /// @param voucherId The ID of the token whose primary sale quantity needs to be updated.
  /// @param sold The amount sold that needs to be subtracted from the remaining quantity._mintGoldDustSetPrice
  function updatePrimarySaleQuantityToSold(uint256 voucherId, uint256 sold) external {
    _checkMarketPlaceCaller(msg.sender);
    uint40 remaining = _voucherMarketData[voucherId].primarySaleL2QuantityToSell;
    if (remaining > 0) {
      _voucherMarketData[voucherId].primarySaleL2QuantityToSell =
        remaining - _safeCastToUint40(sold);
    }
  }

  function setTokenWasSold(uint256 voucherId) public {
    _checkMarketPlaceCaller(msg.sender);
    _voucherMarketData[voucherId].tokenWasSold = true;
  }

  /// @notice Sets the `_mintGoldDustSetPrice` address.
  /// @dev Must be called only once, but not in initializer.
  /// @param mintGoldDustSetPrice_ the address to be set.
  function setMintGoldDustSetPrice(address mintGoldDustSetPrice_) external isOwner {
    require(_mintGoldDustSetPrice == address(0), "Already set!");
    _mintGoldDustSetPrice = mintGoldDustSetPrice_;
  }

  /// @notice that this function is used for the Mint Gold Dust owner
  /// create the dependence of the Mint Gold Dust Marketplace Auction address.
  /// @param mintGoldDustMarketplaceAuction_ the address to be set.
  function setMintGoldDustMarketplaceAuction(address mintGoldDustMarketplaceAuction_)
    external
    isOwner
  {
    require(_mintGoldDustMarketplaceAuction == address(0), "Already set!");
    _mintGoldDustMarketplaceAuction = mintGoldDustMarketplaceAuction_;
  }

  /// @notice Pause the contract
  function pauseContract() external isOwner {
    _pause();
  }

  /// @notice Unpause the contract
  function unpauseContract() external isOwner {
    _unpause();
  }

  function _executeMintFlow(
    address owner,
    uint256 representedAmount,
    MgdL1MarketData memory tokenData,
    uint256 generatedL1VoucherId,
    string memory tokenURI,
    bytes memory memoir
  )
    internal
    virtual
    returns (uint256 voucherId);

  function _executeSplitMintFlow(
    uint256 voucherId,
    address[] memory collaborators,
    uint256[] memory collabsPercentage
  )
    internal
    virtual
  {
    uint40 collabCount;
    // Keep track of the total percentage assigned to collaborators.
    uint256 totalPercentage;

    for (uint256 i = 0; i < collaborators.length; i++) {
      CommonCheckers.checkZeroAddress(collaborators[i]);
      CommonCheckers.checkGtZero(collabsPercentage[i]);

      collabCount++;
      totalPercentage += collabsPercentage[i];

      // Store the percentage for each valid collaborator
      _voucherMarketData[voucherId].collabs[i] = collaborators[i];
      _voucherMarketData[voucherId].collabsPercentage[i] = collabsPercentage[i];
    }

    // Artist's percentage must be greater than zero
    CommonCheckers.checkGtZero(collabsPercentage[collabCount]);

    require(collabCount >= 1, "Add more than 1 owner!");
    require(collabCount < 5, "Add max 4!");

    // `collabPercentages.length` is always `collaborators.length` + 1.
    // Therefore, we make one last addition.
    totalPercentage += collabsPercentage[collabCount];

    if (totalPercentage != 100e18) {
      revert MgdL2Voucher__executeSplitMintFlow_failedPercentSumCheck();
    }

    _voucherMarketData[voucherId].collabsQuantity = collabCount + 1;
    _voucherMarketData[voucherId].collabsPercentage[collabCount] = collabsPercentage[collabCount];

    _voucherMarketData[voucherId].hasCollabs = true;
    emit MintGoldDustNftMintedAndSplitted(
      voucherId, collaborators, collabsPercentage, address(this)
    );
  }

  function _safeCastToUint40(uint256 value) internal pure returns (uint40) {
    require(value <= type(uint40).max, "Value exceeds uint40");
    return uint40(value);
  }

  /// @dev Revert if caller is not a marketplace
  function _checkMarketPlaceCaller(address caller) internal view {
    if (caller != _mintGoldDustMarketplaceAuction || caller != _mintGoldDustSetPrice) {
      revert MgdL2Voucher__notAuthorized("marketplace");
    }
  }

  /// @dev Revert if `royalty` percentage is greater than the max royalty percentage
  function _checkRoyalty(uint256 royalty) internal view {
    if (royalty > _mgdCompany.maxRoyalty()) {
      revert MgdL2Voucher__checkRoyalty_moreThanMax();
    }
  }
}
