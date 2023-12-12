// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from
  "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {MgdCompanyL2Sync} from "./MgdCompanyL2Sync.sol";

struct MgdL1NFTData {
  address artist;
  bool hasTokenCollabs;
  bool tokenWasSold;
  uint40 tokenIdCollabsQuantity;
  uint40 primarySaleQuantityToSold;
  uint256 tokenIdRoyaltyPercent;
  address[4] collabs;
  uint256[5] collabsPercentage;
}

error RoyaltyInvalidPercentage();
error UnauthorizedOnNFT(string message);
error NumberOfCollaboratorsAndPercentagesNotMatch();
error TheTotalPercentageCantBeGreaterOrLessThan100();

abstract contract MgdL2NFT is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  /**
   * @dev Emit when minting.
   */
  event MintGoldDustNFTMinted(
    uint256 indexed tokenId,
    string tokenURI,
    address owner,
    uint256 royalty,
    uint256 amount,
    bool isERC721,
    uint256 collectorMintId,
    bytes memoir
  );
  /**
   * @notice Emit split minting.
   */
  event MintGoldDustNftMintedAndSplitted(
    uint256 indexed tokenId,
    address[] collaborators,
    uint256[] ownersPercentage,
    address contractAddress
  );
  /**
   * @dev Emit when burning.
   */
  event TokenBurned(
    uint256 indexed tokenId, bool isERC721, address owner, address burner, uint256 amount
  );

  MgdCompanyL2Sync internal _mgdCompany;
  address private mintGoldDustSetPriceAddress;
  address private mintGoldDustMarketplaceAuctionAddress;

  mapping(uint256 => address) public tokenIdArtist;
  mapping(uint256 => uint256) public tokenIdRoyaltyPercent;

  mapping(uint256 => bytes) public tokenIdMemoir;

  mapping(uint256 => address[4]) public tokenCollaborators;
  mapping(uint256 => uint256[5]) public tokenIdCollaboratorsPercentage;

  mapping(uint256 => bool) public hasTokenCollaborators;
  mapping(uint256 => uint256) public tokenIdCollaboratorsQuantity;

  mapping(uint256 => bool) internal tokenWasSold;

  mapping(uint256 => uint256) internal primarySaleQuantityToSold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ___gap;

  /**
   *
   * @notice that the MintGoldDustERC721 is composed by other contract.
   * @param mgdCompanyL2Sync The contract responsible to MGD management features.
   */
  function initialize(address mgdCompanyL2Sync)
    internal
    onlyInitializing
    isZeroAddress(mgdCompanyL2Sync)
  {
    __ReentrancyGuard_init();
    __Pausable_init();
    _mgdCompany = MgdCompanyL2Sync(payable(mgdCompanyL2Sync));
  }

  /// @notice Reduces the quantity of remaining items available for primary sale for a specific token.
  ///         Only executes the update if there is a non-zero quantity of the token remaining for primary sale.
  /// @dev This function should only be called by authorized addresses.
  /// @param _tokenId The ID of the token whose primary sale quantity needs to be updated.
  /// @param _amountSold The amount sold that needs to be subtracted from the remaining quantity.
  function updatePrimarySaleQuantityToSold(uint256 _tokenId, uint256 _amountSold) external {
    require(
      msg.sender == mintGoldDustMarketplaceAuctionAddress
        || msg.sender == mintGoldDustSetPriceAddress,
      "Unauthorized on NFT"
    );
    if (primarySaleQuantityToSold[_tokenId] > 0) {
      primarySaleQuantityToSold[_tokenId] = primarySaleQuantityToSold[_tokenId] - _amountSold;
    }
  }

  /// @notice that this function is used for the Mint Gold Dust owner
  /// create the dependence of the Mint Gold Dust set price contract address.
  /// @param _mintGoldDustSetPriceAddress the address to be setted.
  function setMintGoldDustSetPriceAddress(address _mintGoldDustSetPriceAddress) external {
    require(msg.sender == _mgdCompany.owner(), "Unauthorized");
    require(address(mintGoldDustSetPriceAddress) == address(0), "Already setted!");
    mintGoldDustSetPriceAddress = _mintGoldDustSetPriceAddress;
  }

  /// @notice that this function is used for the Mint Gold Dust owner
  /// create the dependence of the Mint Gold Dust Marketplace Auction address.
  /// @param _mintGoldDustMarketplaceAuctionAddress the address to be setted.
  function setMintGoldDustMarketplaceAuctionAddress(address _mintGoldDustMarketplaceAuctionAddress)
    external
  {
    require(msg.sender == _mgdCompany.owner(), "Unauthorized");
    require(address(mintGoldDustMarketplaceAuctionAddress) == address(0), "Already setted!");
    mintGoldDustMarketplaceAuctionAddress = _mintGoldDustMarketplaceAuctionAddress;
  }

  function setTokenWasSold(uint256 _tokenId) public {
    require(
      msg.sender == mintGoldDustMarketplaceAuctionAddress
        || msg.sender == mintGoldDustSetPriceAddress,
      "Unauthorized on NFT"
    );
    tokenWasSold[_tokenId] = true;
  }

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external virtual;

  function _executeMintFlow(
    string calldata _tokenURI,
    uint256 _royaltyPercent,
    uint256 _amount,
    address _artistAddress,
    uint256 _collectorMintId,
    bytes calldata _memoir
  )
    internal
    virtual
    returns (uint256);

  /**
   * @notice that is the function responsible by the mint a new MintGoldDustNFT token.
   * @dev that is a virtual function that MUST be implemented by the NFT contracts childrens.
   * @param _tokenURI the URI that contains the metadata for the NFT.
   * @param _royaltyPercent the royalty percentage to be applied for this NFT secondary sales.
   * @param _amount the quantity to be minted for this token.
   */
  function mintNft(
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
    uint256 newTokenId =
      _executeMintFlow(_tokenURI, _royaltyPercent, _amount, msg.sender, 0, _memoir);

    return newTokenId;
  }

  /**
   * @notice that is the function responsible by the mint and split a new MintGoldDustNFT token.
   * @dev that it receives two arrays one with the _newOwners that are the collaborators for this NFT
   *      and the _ownersPercentage that is the percentage of participation for each collaborators.
   *      @notice that the _newOwners array MUST always have the length equals the _ownersPercentage length minus one.
   *              it is because the fist collaborators we already have that is the creator of the NFT and is saved in
   *              the tokenIdArtist mapping.
   * @param _tokenURI the URI that contains the metadata for the NFT.
   * @param _royalty the royalty percentage to be applied for this NFT secondary sales.
   * @param _newOwners an array of address that can be a number of maximum 4 collaborators.
   * @param _ownersPercentage an array of uint256 that are the percetages for the artist and for each one of the collaborators.
   *    @dev @notice that the percetages will be applied in order that the f position 0 is the percetage for the artist and
   *                 the others will match with the _newOwners array order.
   * @param _amount the quantity to be minted for this token.
   */
  function splitMint(
    string calldata _tokenURI,
    uint256 _royalty,
    address[] calldata _newOwners,
    uint256[] calldata _ownersPercentage,
    uint256 _amount,
    bytes calldata _memoir
  )
    external
    whenNotPaused
    arrayLengthCheck(_newOwners, _ownersPercentage)
    returns (uint256)
  {
    uint256 _tokenId = mintNft(_tokenURI, _royalty, _amount, _memoir);
    _executeSplitMintFlow(_tokenId, _newOwners, _ownersPercentage);
    return _tokenId;
  }

  function _executeSplitMintFlow(
    uint256 _tokenId,
    address[] calldata _newOwners,
    uint256[] calldata _ownersPercentage
  )
    private
  {
    uint256 ownersCount = 0;
    /// @dev it is a new variable to keep track of the total percentage assigned to collaborators.
    uint256 totalPercentage = 0;

    for (uint256 i = 0; i < _newOwners.length; i++) {
      require(_newOwners[i] != address(0), "Owner address cannot be null!");
      require(_ownersPercentage[i] > 0, "Owner percentage must be greater than zero!");

      ownersCount++;
      totalPercentage += _ownersPercentage[i];
      /// @dev Accumulate the percentage for each valid collaborator
      tokenCollaborators[_tokenId][i] = _newOwners[i];
      tokenIdCollaboratorsPercentage[_tokenId][i] = _ownersPercentage[i];
    }

    require(_ownersPercentage[ownersCount] > 0, "Owner percentage must be greater than zero!");

    require(ownersCount >= 1, "Add more than 1 owner!");

    require(ownersCount < 5, "Add max 4!");

    /// @dev the array of percentages is always one number greater than the collaborators length.
    /// So is necessary do one more addition here.
    totalPercentage += _ownersPercentage[ownersCount];

    if (totalPercentage != 100e18) {
      revert TheTotalPercentageCantBeGreaterOrLessThan100();
    }

    tokenIdCollaboratorsQuantity[_tokenId] = ownersCount + 1;
    tokenIdCollaboratorsPercentage[_tokenId][ownersCount] = _ownersPercentage[ownersCount];

    hasTokenCollaborators[_tokenId] = true;
    emit MintGoldDustNftMintedAndSplitted(_tokenId, _newOwners, _ownersPercentage, address(this));
  }

  /// @notice Pause the contract
  function pauseContract() external isowner {
    _pause();
  }

  /// @notice Unpause the contract
  function unpauseContract() external isowner {
    _unpause();
  }

  /// @notice that this modifier is used to check if the arrays length are valid
  /// @dev the _ownersPercentage array length MUST be equals the _newOwners array length plus one
  modifier arrayLengthCheck(address[] calldata _newOwners, uint256[] calldata _ownersPercentage) {
    if (_ownersPercentage.length != _newOwners.length + 1) {
      revert NumberOfCollaboratorsAndPercentagesNotMatch();
    }
    _;
  }

  /// @notice that this modifier is used to check if the address is the owner
  modifier isowner() {
    if (msg.sender != _mgdCompany.owner()) {
      revert UnauthorizedOnNFT("OWNER");
    }
    _;
  }

  /// @notice that this modifier is used to check if the percentage is not greater than the max royalty percentage
  modifier validPercentage(uint256 percentage) {
    if (percentage > _mgdCompany.maxRoyalty()) {
      revert RoyaltyInvalidPercentage();
    }
    _;
  }

  /// @notice that this modifier is used to check if the address is whitelisted
  modifier isArtistWhitelisted(address _artistAddress) {
    if (!_mgdCompany.isArtistApproved(_artistAddress)) {
      revert UnauthorizedOnNFT("ARTIST");
    }
    _;
  }

  /// @notice that this modifier do a group of verifications for the collector mint flow
  modifier checkParameters(address _sender, address _artistAddress, uint256 percentage) {
    if (!_mgdCompany.isArtistApproved(_artistAddress) || _artistAddress == address(0)) {
      revert UnauthorizedOnNFT("ARTIST");
    }
    if (msg.sender == address(0)) {
      revert UnauthorizedOnNFT("CONTRACT");
    }
    if (percentage > _mgdCompany.maxRoyalty()) {
      revert RoyaltyInvalidPercentage();
    }
    _;
  }

  /// @notice that this modifier is used to check if the address is the Mint Gold Dust set price contract address
  /// @dev it is used by the collectorMint flows
  modifier onlySetPrice() {
    if (msg.sender != mintGoldDustSetPriceAddress) {
      revert UnauthorizedOnNFT("SET_PRICE");
    }
    _;
  }

  /// @notice that this modifier is used to check if the address is not zero address
  modifier isZeroAddress(address _address) {
    require(_address != address(0), "address is zero address");
    _;
  }
}
