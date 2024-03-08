// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "./utils/FileSystem.s.sol";
import {MgdScriptConstants} from "./MgdScriptConstants.s.sol";
import {TypeNFT} from "../../src/voucher/VoucherDataTypes.sol";
import {Upgrader} from "./tasks/Upgrader.s.sol";

import "./deploy/MgdDeployLibraries.s.sol";

enum Action {
  NOTHING,
  DEPLOY,
  UPGRADE,
  CONFIGURE
}

struct ContractActionConfiguration {
  Action company;
  Action memoir;
  Action escrow;
  Action mgd721;
  Action mgd1155;
  Action mgdVoucher721;
  Action mgdVoucher1155;
  Action mgdSetPrice;
  Action mgdAuction;
}

/**
 * @dev Run using shell command:
 * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
 * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/GlobalDeployerScript.s.sol
 */
contract GlobalDeployerScript is FileSystem, MgdScriptConstants {
  FileSystem fs;

  ContractActionConfiguration config = ContractActionConfiguration({
    company: Action.NOTHING,
    memoir: Action.NOTHING,
    escrow: Action.NOTHING,
    mgd721: Action.NOTHING,
    mgd1155: Action.NOTHING,
    mgdVoucher721: Action.NOTHING,
    mgdVoucher1155: Action.NOTHING,
    mgdSetPrice: Action.NOTHING,
    mgdAuction: Action.NOTHING
  });

  function run() public {
    fs = new FileSystem();

    // Set this to true if you want to deploy the marketplace with vouchers
    // otherwise, it will deploy the marketplace with the standard NFTs
    bool marketPlaceWithVouchers = false;

    vm.startBroadcast();
    executeDeployActions(marketPlaceWithVouchers);
    executeConfigureActions();
    executeUpgradeActions();
    vm.stopBroadcast();
  }

  function executeDeployActions(bool marketPlaceWithVouchers) internal {
    string memory chainName = fs.getChainName(block.chainid);
    string memory pairChain = fs.getPairChainName(block.chainid);

    // MgdCompanyL2Sync
    if (config.company == Action.DEPLOY) {
      MgdCompanyL2SyncParams memory params = MgdCompanyL2SyncParams({
        owner: msg.sender,
        primarySaleFeePercent: _PRIMARY_SALE_FEE_PERCENT,
        secondarySaleFeePercent: _SECONDARY_SALE_FEE_PERCENT,
        collectorFee: _COLLECTOR_FEE,
        maxRoyalty: _MAX_ROYALTY,
        auctionDurationInMinutes: _AUCTION_DURATION,
        auctionFinalMinute: _AUCTION_EXTENSION
      });
      MgdCompanyL2Sync company = MgdCompanyL2SyncDeployer.deployMgdCompanyL2Sync(fs, params, false);
      company.setMessenger(getSafeAddress("Messenger", chainName));
    }
    // MintGoldDustMemoir
    if (config.memoir == Action.DEPLOY) {
      MintGoldDustMemoirDeployer.deployMintGoldDustMemoir(fs, false);
    }
    // MgdL2NFTEscrow
    if (config.escrow == Action.DEPLOY) {
      MgdL2NFTEscrowParams memory params =
        MgdL2NFTEscrowParams({mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName)});
      MgdL2NFTEscrowDeployer.deployMgdL2NFTEscrow(fs, params, false);
    }
    // MgdERC721PermitEscrowable
    if (config.mgd721 == Action.DEPLOY) {
      MgdERC721PermitEscrowableParams memory params = MgdERC721PermitEscrowableParams({
        mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName)
      });
      MgdERC721PermitEscrowableDeployer.deployMgdERC721PermitEscrowable(fs, params, false);
    }
    // MgdERC1155PermitEscrowable
    if (config.mgd1155 == Action.DEPLOY) {
      MgdERC1155PermitEscrowableParams memory params = MgdERC1155PermitEscrowableParams({
        mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName),
        baseURI: _BASE_URI
      });
      MgdERC1155PermitEscrowableDeployer.deployMgdERC1155PermitEscrowable(fs, params, false);
    }
    // Mgd721L2Voucher
    if (config.mgdVoucher721 == Action.DEPLOY) {
      Mgd721L2VoucherParams memory params = Mgd721L2VoucherParams({
        mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName),
        mgdL2NFTescrow: getSafeAddress("MgdL2NFTEscrow", pairChain),
        mgdERC721: getSafeAddress("MgdERC721PermitEscrowable", pairChain),
        crossDomainMessenger: getSafeAddress("Messenger", chainName)
      });
      Mgd721L2VoucherDeployer.deployMgd721L2Voucher(fs, params, false);
    }
    // Mgd1155L2Voucher
    if (config.mgdVoucher1155 == Action.DEPLOY) {
      Mgd1155L2VoucherParams memory params = Mgd1155L2VoucherParams({
        mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName),
        mgdL2NFTescrow: getSafeAddress("MgdL2NFTEscrow", pairChain),
        mgdERC1155: getSafeAddress("MgdERC1155PermitEscrowable", pairChain),
        crossDomainMessenger: getSafeAddress("Messenger", chainName)
      });
      Mgd1155L2VoucherDeployer.deployMgd1155L2Voucher(fs, params, false);
    }
    // MintGoldDustSetPrice
    if (config.mgdSetPrice == Action.DEPLOY) {
      MintGoldDustSetPriceParams memory params;
      params.mintGoldDustCompany = getSafeAddress("MgdCompanyL2Sync", chainName);
      params.mintGoldDustERC721Address = payable(
        getSafeAddress(
          marketPlaceWithVouchers ? "Mgd721L2Voucher" : "MgdERC721PermitEscrowable", chainName
        )
      );
      params.mintGoldDustERC1155Address = payable(
        getSafeAddress(
          marketPlaceWithVouchers ? "Mgd1155L2Voucher" : "MgdERC1155PermitEscrowable", chainName
        )
      );
      MintGoldDustSetPriceDeployer.deployMintGoldDustSetPrice(fs, params, false);
    }
    // MintGoldDustMarketplaceAuction
    if (config.mgdAuction == Action.DEPLOY) {
      MintGoldDustMarketplaceAuctionParams memory params;
      params.mintGoldDustCompany = getSafeAddress("MgdCompanyL2Sync", chainName);
      params.mintGoldDustERC721Address = payable(
        getSafeAddress(
          marketPlaceWithVouchers ? "Mgd721L2Voucher" : "MgdERC721PermitEscrowable", chainName
        )
      );
      params.mintGoldDustERC1155Address = payable(
        getSafeAddress(
          marketPlaceWithVouchers ? "Mgd1155L2Voucher" : "MgdERC1155PermitEscrowable", chainName
        )
      );
      MintGoldDustMarketplaceAuctionDeployer.deployMintGoldDustMarketplaceAuction(fs, params, false);
    }
  }

  function executeConfigureActions() internal {
    string memory chainName = fs.getChainName(block.chainid);
    string memory pairChain = fs.getPairChainName(block.chainid);

    // MgdCompanyL2Sync
    if (config.company == Action.CONFIGURE) {
      MgdCompanyL2Sync company = MgdCompanyL2Sync(getSafeAddress("MgdCompanyL2Sync", chainName));
      if (address(company.messenger()) == address(0)) {
        company.setMessenger(getSafeAddress("Messenger", chainName));
        console.log("Done! setting `messenger` in MgdCompanyL2Sync.");
      }
      company.setCrossDomainMGDCompany(getSafeAddress("MgdCompanyL2Sync", pairChain));
      console.log("Done! setting `crossDomainMGDCompany` in MgdCompanyL2Sync!");
      company.setPublicKey(_MGD_SIGNER);
      console.log("Done! setting `publicKey` in MgdCompanyL2Sync!");
    }
    // MgdL2NFTEscrow
    if (config.escrow == Action.CONFIGURE) {
      MgdL2NFTEscrow escrow = MgdL2NFTEscrow(getSafeAddress("MgdL2NFTEscrow", chainName));
      if (escrow.voucher721L2() == address(0)) {
        escrow.setVoucherL2(getSafeAddress("Mgd721L2Voucher", pairChain), TypeNFT.ERC721);
        console.log("Done! setting `voucher721L2` in MgdL2NFTEscrow!");
      }

      if (escrow.voucher1155L2() == address(0)) {
        escrow.setVoucherL2(getSafeAddress("Mgd1155L2Voucher", pairChain), TypeNFT.ERC1155);
        console.log("Done! setting `voucher1155L2` in MgdL2NFTEscrow!");
      }
    }
    // MgdERC721PermitEscrowable
    if (config.mgd721 == Action.CONFIGURE) {
      MgdERC721PermitEscrowable mgd721 =
        MgdERC721PermitEscrowable(getSafeAddress("MgdERC721PermitEscrowable", chainName));
      mgd721.setMintGoldDustSetPriceAddress(getSafeAddress("MintGoldDustSetPrice", chainName));
      console.log("Done! setting `MintGoldDustSetPrice` in Mgd721!");
      mgd721.setMintGoldDustMarketplaceAuctionAddress(
        getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
      );
      console.log("Done! setting `MintGoldDustMarketplaceAuction` in Mgd721!");

      if (mgd721.escrow() == address(0)) {
        mgd721.setEscrow(getSafeAddress("MgdL2NFTEscrow", chainName));
        console.log("Done! setting `escrow` in Mgd721!");
      }
    }
    // MgdERC1155PermitEscrowable
    if (config.mgd1155 == Action.CONFIGURE) {
      MgdERC1155PermitEscrowable mgd1155 =
        MgdERC1155PermitEscrowable(getSafeAddress("MgdERC1155PermitEscrowable", chainName));
      mgd1155.setMintGoldDustSetPriceAddress(getSafeAddress("MintGoldDustSetPrice", chainName));
      console.log("Done! setting `MintGoldDustSetPrice` in Mgd1155!");
      mgd1155.setMintGoldDustMarketplaceAuctionAddress(
        getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
      );
      console.log("Done! setting `MintGoldDustMarketplaceAuction` in Mgd1155!");
      if (mgd1155.escrow() == address(0)) {
        mgd1155.setEscrow(getSafeAddress("MgdL2NFTEscrow", chainName));
        console.log("Done! setting `escrow` in Mgd1155!");
      }
    }
    // Mgd721L2Voucher
    if (config.mgdVoucher721 == Action.CONFIGURE) {
      Mgd721L2Voucher mgd721Voucher = Mgd721L2Voucher(getSafeAddress("Mgd721L2Voucher", chainName));
      mgd721Voucher.setMintGoldDustSetPrice(getSafeAddress("MintGoldDustSetPrice", chainName));
      console.log("Done! setting `MintGoldDustSetPrice` in mgd721Voucher!");
      mgd721Voucher.setMintGoldDustMarketplaceAuction(
        getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
      );
      console.log("Done! setting `MintGoldDustMarketplaceAuction` in mgd721Voucher!");
    }
    // Mgd1155L2Voucher
    if (config.mgdVoucher1155 == Action.CONFIGURE) {
      Mgd1155L2Voucher mgd1155Voucher =
        Mgd1155L2Voucher(getSafeAddress("Mgd1155L2Voucher", chainName));
      mgd1155Voucher.setMintGoldDustSetPrice(getSafeAddress("MintGoldDustSetPrice", chainName));
      console.log("Done! setting `MintGoldDustSetPrice` in mgd1155Voucher!");
      mgd1155Voucher.setMintGoldDustMarketplaceAuction(
        getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
      );
      console.log("Done! setting `MintGoldDustMarketplaceAuction` in mgd1155Voucher!");
    }
    // MintGoldDustSetPrice
    if (config.mgdSetPrice == Action.CONFIGURE) {
      MintGoldDustSetPrice setPrice =
        MintGoldDustSetPrice(getSafeAddress("MintGoldDustSetPrice", chainName));
      setPrice.setMintGoldDustMarketplace(
        getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
      );
      console.log("Done! setting `MintGoldDustMarketplace` in mgdSetPrice!");
    }
    // MintGoldDustMarketplaceAuction
    if (config.mgdAuction == Action.CONFIGURE) {
      MintGoldDustMarketplaceAuction auction =
        MintGoldDustMarketplaceAuction(getSafeAddress("MintGoldDustMarketplaceAuction", chainName));
      auction.setMintGoldDustMarketplace(getSafeAddress("MintGoldDustSetPrice", chainName));
      console.log("Done! setting `MintGoldDustMarketplace` in mgdAuction!");
    }
  }

  function executeUpgradeActions() internal {
    string memory chainName = fs.getChainName(block.chainid);

    // MgdCompanyL2Sync
    if (config.company == Action.UPGRADE) {
      address companyProxy = getSafeAddress("MgdCompanyL2Sync", chainName);
      MgdCompanyL2SyncParams memory emptyParams;
      address newImpl =
        address(MgdCompanyL2SyncDeployer.deployMgdCompanyL2Sync(fs, emptyParams, true));
      Upgrader.upgrade(fs, companyProxy, newImpl);
    }
    // MintGoldDustMemoir
    if (config.memoir == Action.UPGRADE) {
      address memoirProxy = getSafeAddress("MintGoldDustMemoir", chainName);
      address newImpl = address(MintGoldDustMemoirDeployer.deployMintGoldDustMemoir(fs, true));
      Upgrader.upgrade(fs, memoirProxy, newImpl);
    }
    // MgdL2NFTEscrow
    if (config.escrow == Action.UPGRADE) {
      address escrowProxy = getSafeAddress("MgdL2NFTEscrow", chainName);
      MgdL2NFTEscrowParams memory emptyParams;
      address newImpl = address(MgdL2NFTEscrowDeployer.deployMgdL2NFTEscrow(fs, emptyParams, true));
      Upgrader.upgrade(fs, escrowProxy, newImpl);
    }
    // MgdERC721PermitEscrowable
    if (config.mgd721 == Action.UPGRADE) {
      address mgd721Proxy = getSafeAddress("MgdERC721PermitEscrowable", chainName);
      MgdERC721PermitEscrowableParams memory emptyParams;
      address newImpl = address(
        MgdERC721PermitEscrowableDeployer.deployMgdERC721PermitEscrowable(fs, emptyParams, true)
      );
      Upgrader.upgrade(fs, mgd721Proxy, newImpl);
    }
    // MgdERC1155PermitEscrowable
    if (config.mgd1155 == Action.UPGRADE) {
      address mgd1155Proxy = getSafeAddress("MgdERC1155PermitEscrowable", chainName);
      MgdERC1155PermitEscrowableParams memory emptyParams;
      address newImpl = address(
        MgdERC1155PermitEscrowableDeployer.deployMgdERC1155PermitEscrowable(fs, emptyParams, true)
      );
      Upgrader.upgrade(fs, mgd1155Proxy, newImpl);
    }
    // Mgd721L2Voucher
    if (config.mgdVoucher721 == Action.UPGRADE) {
      address mgd721VoucherProxy = getSafeAddress("Mgd721L2Voucher", chainName);
      Mgd721L2VoucherParams memory emptyParams;
      address newImpl =
        address(Mgd721L2VoucherDeployer.deployMgd721L2Voucher(fs, emptyParams, true));
      Upgrader.upgrade(fs, mgd721VoucherProxy, newImpl);
    }
    // Mgd1155L2Voucher
    if (config.mgdVoucher1155 == Action.UPGRADE) {
      address mgd1155VoucherProxy = getSafeAddress("Mgd1155L2Voucher", chainName);
      Mgd1155L2VoucherParams memory emptyParams;
      address newImpl =
        address(Mgd1155L2VoucherDeployer.deployMgd1155L2Voucher(fs, emptyParams, true));
      Upgrader.upgrade(fs, mgd1155VoucherProxy, newImpl);
    }
    // MintGoldDustSetPrice
    if (config.mgdSetPrice == Action.UPGRADE) {
      address setPriceProxy = getSafeAddress("MintGoldDustSetPrice", chainName);
      MintGoldDustSetPriceParams memory emptyParams;
      address newImpl =
        address(MintGoldDustSetPriceDeployer.deployMintGoldDustSetPrice(fs, emptyParams, true));
      Upgrader.upgrade(fs, setPriceProxy, newImpl);
    }
    // MintGoldDustMarketplaceAuction
    if (config.mgdAuction == Action.UPGRADE) {
      address auctionProxy = getSafeAddress("MintGoldDustMarketplaceAuction", chainName);
      MintGoldDustMarketplaceAuctionParams memory emptyParams;
      address newImpl = address(
        MintGoldDustMarketplaceAuctionDeployer.deployMintGoldDustMarketplaceAuction(
          fs, emptyParams, true
        )
      );
      Upgrader.upgrade(fs, auctionProxy, newImpl);
    }
  }

  function getSafeAddress(
    string memory contractLabel,
    string memory chainName
  )
    private
    returns (address)
  {
    try fs.getAddress(contractLabel, chainName) returns (address addr) {
      return addr;
    } catch {
      revert FileNotFound(chainName, contractLabel);
    }
  }
}
