// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
  "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {MgdCompanyL2Sync} from "./../MgdCompanyL2Sync.sol";

struct MgdL1NFTData {
  address artist;
  bool hasCollabs;
  bool tokenWasSold;
  uint40 collabsQuantity;
  uint40 primarySaleQuantityToSell;
  uint128 representedAmount;
  uint128 royaltyPercent;
  address[4] collabs;
  uint256[5] collabsPercentage;
}

abstract contract MgdL2NFT is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
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
  error MgdL2NFT__checkZeroAddress_notAllowed();
  error MgdL2NFT__checkGtZero_notZero();
  error MgdL2NFT__executeSplitMintFlow_failedPercentSumCheck();
  error MgdL2NFT__notAuthorized(string restriction);
  error MgdL2NFT__checkRoyalty_moreThanMax();
  error MgdL2NFT__splitMint_invalidArray();
  error MgdL2NFT__collectorMint_disabledInL2();

  MgdCompanyL2Sync internal _mgdCompany;
  address private _mintGoldDustSetPrice;
  address private _mintGoldDustMarketplaceAuction;

  // voucherId => bool isNative
  mapping(uint256 => bool) private _natives;

  // voucherId => struct MgdL1NFTData
  mapping(uint256 => MgdL1NFTData) internal _voucherData;
  mapping(uint256 => bytes) internal _tokenIdMemoir;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @dev Revert if caller is the {mgdCompany.owner()}
  modifier isOwner() {
    if (msg.sender != _mgdCompany.owner()) {
      revert MgdL2NFT__notAuthorized("owner");
    }
    _;
  }

  /// @dev Revert if caller is not a whitelisted artist
  modifier isArtistWhitelisted(address _artistAddress) {
    if (!_mgdCompany.isArtistApproved(_artistAddress)) {
      revert MgdL2NFT__notAuthorized("artist");
    }
    _;
  }

  /// @dev Initializes the contract by setting `_mgdCompany`
  function __MgdL2NFT_init(address mgdCompanyL2Sync) internal onlyInitializing {
    _checkZeroAddress(mgdCompanyL2Sync);
    __ReentrancyGuard_init();
    __Pausable_init();
    _mgdCompany = MgdCompanyL2Sync(payable(mgdCompanyL2Sync));
  }

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external virtual;

  function getVoucherData(uint256 id) public view returns (MgdL1NFTData memory) {
    return _voucherData[id];
  }

  function isVoucherNative(uint256 id) public view returns (bool) {
    return _natives[id];
  }

  function tokenIdMemoir(uint256 id) public view returns (bytes memory) {
    return _tokenIdMemoir[id];
  }

  /// @notice Mint a native voucher that represents a new MintGoldDustNFT token in a L2.
  /// @param tokenURI the URI that contains the metadata for the NFT.
  /// @param royalty percentage to be applied for this NFT secondary sales.
  /// @param amount the quantity to be minted for this token.
  /// @param memoir for this mint
  function mintNft(
    string memory tokenURI,
    uint128 royalty,
    uint40 amount,
    bytes memory memoir
  )
    public
    payable
    virtual
    isArtistWhitelisted(msg.sender)
    whenNotPaused
    returns (uint256)
  {
    _checkRoyalty(royalty);
    MgdL1NFTData memory tokenData = MgdL1NFTData({
      artist: msg.sender,
      hasCollabs: false,
      tokenWasSold: false,
      collabsQuantity: 0,
      primarySaleQuantityToSell: amount,
      representedAmount: amount,
      royaltyPercent: royalty,
      collabs: [address(0), address(0), address(0), address(0)],
      collabsPercentage: [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]
    });
    uint256 voucherId = _executeMintFlow(msg.sender, tokenData, 0, tokenURI, memoir);
    _natives[voucherId] = true;
    return voucherId;
  }

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
    string calldata tokenURI,
    uint128 royalty,
    address[] calldata collaborators,
    uint256[] calldata collabsPercentage,
    uint40 amount,
    bytes calldata memoir
  )
    public
    virtual
    whenNotPaused
    returns (uint256)
  {
    if (collabsPercentage.length != collaborators.length + 1) {
      revert MgdL2NFT__splitMint_invalidArray();
    }
    uint256 voucherId = mintNft(tokenURI, royalty, amount, memoir);
    _executeSplitMintFlow(voucherId, collaborators, collabsPercentage);
    _natives[voucherId] = true;
    return voucherId;
  }

  /// @notice Collector mint is disabled in MGD L2 contracts.
  /// @dev  Kept this function to throw error message when called
  /// by other MGD v2-core unchanged contracts.
  function collectorMint(
    string calldata,
    uint256,
    uint256,
    address,
    bytes calldata,
    uint256,
    address
  )
    external
    pure
    returns (uint256)
  {
    revert MgdL2NFT__splitMint_invalidArray();
  }

  /// @notice Collector split mint is disabled in MGD L2 contracts.
  /// @dev  Kept this function to throw error message when called
  /// by other MGD v2-core unchanged contracts.
  function collectorSplitMint(
    string calldata,
    uint256,
    address[] calldata,
    uint256[] calldata,
    uint256,
    address,
    bytes calldata,
    uint256,
    address
  )
    external
    pure
    returns (uint256)
  {
    revert MgdL2NFT__collectorMint_disabledInL2();
  }

  /// @notice Reduces the quantity of remaining items available for primary sale for a specific token.
  ///         Only executes the update if there is a non-zero quantity of the token remaining for primary sale.
  /// @dev This function must only be called by authorized marketplace related addresses.
  /// @param voucherId The ID of the token whose primary sale quantity needs to be updated.
  /// @param sold The amount sold that needs to be subtracted from the remaining quantity._mintGoldDustSetPrice
  function updateprimarySaleQuantityToSell(uint256 voucherId, uint256 sold) external {
    _checkMarketPlaceCaller(msg.sender);
    uint40 remaining = _voucherData[voucherId].primarySaleQuantityToSell;
    if (remaining > 0) {
      _voucherData[voucherId].primarySaleQuantityToSell = remaining - uint40(sold);
    }
  }

  function setTokenWasSold(uint256 voucherId) public {
    _checkMarketPlaceCaller(msg.sender);
    _voucherData[voucherId].tokenWasSold = true;
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

  function _executeMintFlow(
    address owner,
    MgdL1NFTData memory tokenData,
    uint256 generatedL1VoucherId,
    string memory tokenURI,
    bytes memory memoir
  )
    internal
    virtual
    returns (uint256 voucherId);

  function _executeSplitMintFlow(
    uint256 voucherId,
    address[] calldata collaborators,
    uint256[] calldata collabsPercentage
  )
    internal
    virtual
  {
    uint40 collabCount;
    // Keep track of the total percentage assigned to collaborators.
    uint256 totalPercentage;

    for (uint256 i = 0; i < collaborators.length; i++) {
      _checkZeroAddress(collaborators[i]);
      _checkGtZero(collabsPercentage[i]);

      collabCount++;
      totalPercentage += collabsPercentage[i];

      // Store the percentage for each valid collaborator
      _voucherData[voucherId].collabs[i] = collaborators[i];
      _voucherData[voucherId].collabsPercentage[i] = collabsPercentage[i];
    }

    // Artist's percentage must be greater than zero
    _checkGtZero(collabsPercentage[collabCount]);

    require(collabCount >= 1, "Add more than 1 owner!");
    require(collabCount < 5, "Add max 4!");

    // `collabPercentages.length` is always `collaborators.length` + 1.
    // Therefore, we make one last addition.
    totalPercentage += collabsPercentage[collabCount];

    if (totalPercentage != 100e18) {
      revert MgdL2NFT__executeSplitMintFlow_failedPercentSumCheck();
    }

    _voucherData[voucherId].collabsQuantity = collabCount + 1;
    _voucherData[voucherId].collabsPercentage[collabCount] = collabsPercentage[collabCount];

    _voucherData[voucherId].hasCollabs = true;
    emit MintGoldDustNftMintedAndSplitted(
      voucherId, collaborators, collabsPercentage, address(this)
    );
  }

  /// @notice Pause the contract
  function pauseContract() external isOwner {
    _pause();
  }

  /// @notice Unpause the contract
  function unpauseContract() external isOwner {
    _unpause();
  }

  function _generateL2NativeIdentifier(MgdL1NFTData memory tokenData)
    internal
    view
    returns (uint256 identifier)
  {
    identifier = uint256(keccak256(abi.encode(blockhash(block.number), tokenData)));
  }

  /// @dev Revert if `addr` is zero
  function _checkZeroAddress(address addr) internal pure {
    if (addr == address(0)) {
      revert MgdL2NFT__checkZeroAddress_notAllowed();
    }
  }

  /// @dev Revert if unsigned `input` is greater than zero
  function _checkGtZero(uint256 input) internal pure {
    if (input == 0) {
      revert MgdL2NFT__checkGtZero_notZero();
    }
  }

  /// @dev Revert if caller is not a marketplace
  function _checkMarketPlaceCaller(address caller) internal view {
    if (caller != _mintGoldDustMarketplaceAuction || caller != _mintGoldDustSetPrice) {
      revert MgdL2NFT__notAuthorized("marketplace");
    }
  }

  /// @dev Revert if `royalty` percentage is greater than the max royalty percentage
  function _checkRoyalty(uint256 royalty) internal view {
    if (royalty > _mgdCompany.maxRoyalty()) {
      revert MgdL2NFT__checkRoyalty_moreThanMax();
    }
  }
}
