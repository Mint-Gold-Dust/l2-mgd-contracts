// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract ScriptConstants {
    uint256 internal constant MAINNET_CHAIN_ID = 1;
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant LOCAL = 31337;

    mapping(uint256 => string) internal _chainNames;
    mapping(uint256 => string) internal _pairChain;

    constructor() {
        _chainNames[MAINNET_CHAIN_ID] = "mainnet";
        _chainNames[SEPOLIA_CHAIN_ID] = "sepolia";
        _chainNames[BASE_CHAIN_ID] = "base";
        _chainNames[BASE_SEPOLIA_CHAIN_ID] = "base-sepolia";
        _chainNames[LOCAL] = "local";

        _pairChain[MAINNET_CHAIN_ID] = "base";
        _pairChain[SEPOLIA_CHAIN_ID] = "base-sepolia";
        _pairChain[BASE_CHAIN_ID] = "mainnet";
        _pairChain[BASE_SEPOLIA_CHAIN_ID] = "sepolia";
        _pairChain[LOCAL] = "local";
    }

    function getChainName(uint256 chainId) public view returns (string memory) {
        return _chainNames[chainId];
    }

    function getPairChain(uint256 chainId) public view returns (string memory) {
        return _pairChain[chainId];
    }
}
