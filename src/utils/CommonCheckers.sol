// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

library CommonCheckers {
  /// Custom Errors
  error CommonCheckers__checkZeroAddress_notAllowed();
  error CommonCheckers__checkGtZero_notZero();

  /// @dev Revert if `addr` is zero
  function checkZeroAddress(address addr) internal pure {
    if (addr == address(0)) {
      revert CommonCheckers__checkZeroAddress_notAllowed();
    }
  }

  /// @notice Checks that unsigned `input` is greater than zero
  function checkGtZero(uint256 input) internal pure {
    if (input == 0) {
      revert CommonCheckers__checkGtZero_notZero();
    }
  }
}
