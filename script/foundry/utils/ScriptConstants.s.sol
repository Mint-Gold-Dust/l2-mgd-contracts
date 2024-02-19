// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract ScriptConstants {
    uint256 internal constant MAINNET_CHAIN_ID = 1;
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant LOCAL = 31337;

    mapping(uint256 => string) internal _chainNames;
    mapping(uint256 => string) internal _pairChainName;
    mapping(uint256 => uint256) internal _pairChainId;

    constructor() {
        _chainNames[MAINNET_CHAIN_ID] = "mainnet";
        _chainNames[SEPOLIA_CHAIN_ID] = "sepolia";
        _chainNames[BASE_CHAIN_ID] = "base";
        _chainNames[BASE_SEPOLIA_CHAIN_ID] = "base-sepolia";
        _chainNames[LOCAL] = "local";

        _pairChainName[MAINNET_CHAIN_ID] = "base";
        _pairChainName[SEPOLIA_CHAIN_ID] = "base-sepolia";
        _pairChainName[BASE_CHAIN_ID] = "mainnet";
        _pairChainName[BASE_SEPOLIA_CHAIN_ID] = "sepolia";
        _pairChainName[LOCAL] = "local";

        _pairChainId[MAINNET_CHAIN_ID] = BASE_CHAIN_ID;
        _pairChainId[SEPOLIA_CHAIN_ID] = BASE_SEPOLIA_CHAIN_ID;
        _pairChainId[BASE_CHAIN_ID] = MAINNET_CHAIN_ID;
        _pairChainId[BASE_SEPOLIA_CHAIN_ID] = SEPOLIA_CHAIN_ID;
        _pairChainId[LOCAL] = LOCAL;
    }

    function getChainName(uint256 chainId) public view returns (string memory) {
        return _chainNames[chainId];
    }

    function getPairChainName(
        uint256 chainId
    ) public view returns (string memory) {
        return _pairChainName[chainId];
    }

    function getPairChainId(uint256 chainId) public view returns (uint256) {
        return _pairChainId[chainId];
    }
}
