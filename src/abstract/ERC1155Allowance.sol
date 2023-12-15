// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

abstract contract ERC1155Allowance {
  ///@dev Emit when `allowance` is set.
  event SetAllowance(
    address indexed owner, address indexed spender, uint256 indexed id, uint256 amount
  );

  /// Custom Errors
  error ERC1155Allowance__spendAllowance_insufficient();
  error ERC1155Allowance__checkZeroAddress_notAllowed();

  // keccak256(abi.encodePacked(owner,spender,tokenId)) => amount
  mapping(bytes32 => uint256) internal _allowance;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private __gap;

  /// @notice Returns the allowance given by `owner` to `operator` for `tokenId`
  /// @dev This call needs to read if `operator` is `ERC721.isApprovedForAll() == true` and return
  ///      type(uint256).max regardless of recorded state in `_allowance`.
  /// @param owner giving allowance
  /// @param operator to check allowance
  /// @param tokenId to check
  function getAllowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    public
    view
    virtual
    returns (uint256);

  /// @notice Allow `msg.sender` for `spender` to `transfer` `tokenId` `amount`.
  /// @param spender of allowance
  /// @param tokenId to give allowance
  /// @param amount to give allowance
  function setAllowance(address spender, uint256 tokenId, uint256 amount) public returns (bool) {
    address owner = msg.sender;
    _setAllowance(owner, spender, tokenId, amount);
    return true;
  }

  function _spendAllowance(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount
  )
    internal
    virtual
  {
    uint256 currentAllowance = _getAllowance(owner, operator, tokenId);
    if (currentAllowance != type(uint256).max) {
      if (amount > currentAllowance) revert ERC1155Allowance__spendAllowance_insufficient();
      unchecked {
        _setAllowance(owner, operator, tokenId, currentAllowance - amount);
      }
    }
  }

  function _setAllowance(
    address owner,
    address spender,
    uint256 tokenId,
    uint256 amount
  )
    internal
    virtual
  {
    _checkZeroAddress(owner);
    _checkZeroAddress(spender);
    _allowance[_hashedOwnerSpenderTokenID(owner, spender, tokenId)] = amount;
    emit SetAllowance(owner, spender, tokenId, amount);
  }

  function _getAllowance(
    address owner,
    address operator,
    uint256 tokenId
  )
    internal
    view
    returns (uint256 allowance)
  {
    allowance = _allowance[_hashedOwnerSpenderTokenID(owner, operator, tokenId)];
  }

  function _hashedOwnerSpenderTokenID(
    address owner,
    address operator,
    uint256 tokenId
  )
    internal
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked(owner, operator, tokenId));
  }

  /// @dev Revert if `addr` is zero
  function _checkZeroAddress(address addr) private pure {
    if (addr == address(0)) revert ERC1155Allowance__checkZeroAddress_notAllowed();
  }
}
