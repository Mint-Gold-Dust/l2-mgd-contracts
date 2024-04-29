import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.PKEY}`],
      chainId: 11155111,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.PKEY}`],
      chainId: 1,
    },
    basesepolia: {
      url: `https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_BASESEPOLIA}`,
      accounts: [`${process.env.PKEY}`],
      chainId: 84532,
    },
    base: {
      url: `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY_BASE}`,
      accounts: [`${process.env.PKEY}`],
      chainId: 8543,
    },
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
      viaIR: true,
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  etherscan: {
    apiKey: {
      sepolia: `${process.env.KEY_MAINNET}`,
      mainnet: `${process.env.KEY_MAINNET}`,
      base: `${process.env.KEY_BASE}`,
      basesepolia: `${process.env.KEY_BASE}`,
    },
  },
};

export default config;
