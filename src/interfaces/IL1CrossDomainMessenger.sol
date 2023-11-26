// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IL1crossDomainMessenger {
  function xDomainMessageSender() external returns (address);
  function sendMessage(address _target, bytes memory _message, uint32 _gasLimit) external;
}
