import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import * as fs from 'fs';

// Task to generate a wallet with a randomly created mnemonic
task("generate", "Create a wallet for builder deploys", async (_, { ethers }) => {
  const newWallet = ethers.Wallet.createRandom();
  const address = newWallet.address;
  const mnemonic = newWallet.mnemonic.phrase
  console.log("🔐 Account Generated as " + address + " and set as mnemonic in packages/hardhat");
  fs.writeFileSync("./" + address + ".txt", `${address}\n${mnemonic.toString()}\n${newWallet.privateKey}`);
  fs.writeFileSync("./mnemonic.txt", mnemonic.toString());
});

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
  },
};

export default config;
