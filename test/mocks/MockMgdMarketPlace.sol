// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ManagePrimarySale} from "mgd-v2-contracts/libraries/MgdMarketPlaceDataTypes.sol";

contract MockMgdMarketPlace {
  mapping(address => mapping(uint256 => ManagePrimarySale)) internal _isSecondarySale;

  function mockSetSecondarySale(
    address contractAddress,
    uint256 tokenId,
    ManagePrimarySale memory secondarySale
  )
    external
  {
    _isSecondarySale[contractAddress][tokenId] = secondarySale;
  }

  /// @notice that this function is used to populate the _isSecondarySale mapping for the
  /// sibling contract. This way the mapping state will be shared.
  /// @param _contractAddress the address of the MintGoldDustERC1155 or MintGoldDustERC721.
  /// @param _tokenId the id of the token.
  /// @param _owner the owner of the token.
  /// @param _sold a boolean that indicates if the token was sold or not.
  /// @param _amount the amount of tokens minted for this token.
  function setSecondarySale(
    address _contractAddress,
    uint256 _tokenId,
    address _owner,
    bool _sold,
    uint256 _amount
  )
    external
  {
    _isSecondarySale[_contractAddress][_tokenId] = ManagePrimarySale(_owner, _sold, _amount);
  }

  function getSecondarySale(
    address contractAddress,
    uint256 tokenId
  )
    external
    view
    returns (ManagePrimarySale memory)
  {
    return _isSecondarySale[contractAddress][tokenId];
  }
}
