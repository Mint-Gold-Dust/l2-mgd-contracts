![Alt text](mgdlogo.png)

## Mint Gold Dust (MGD) L2 Smart Contracts Suite

**MGD is a decentralized NFT ecosystem built for artists and collectors.**

This repository contains the smart contracts that allow MGD to operate both in Ethereum and an Op-stack compatible layer 2 (such as [Base](https://base.org/) or [Optimism](https://www.optimism.io/)).

The smart contracts in this repository introduce the following high level functionality:

- **NFT Portability**: Bring your MGD NFTs from Ethereum to the L2 or viceverse via an escrow-voucher contract system.
- **L2 Usability**: Create, sell, or auction your art in more exciting and different ways, not to mention also affordable, by using the MGD L2 ecosystem.
- **Simpler Transferability**: Approve the sell, auction or transfer of your NFTs with the use of "permits" or signatures, instead of the current additional approval transaction.

## Documentation

General statements

- These smart contracts are backward compatible (must be) with the MGD v2-core contracts.
- Ethereum is and will be MGD's ultimate layer of truth. This assures all our artists and collectors that their creations or collected art pieces will persist regardless of the direction any L2 takes in the future (including ceasing to exist).

## Audits

WIP

## Testing

```
forge test --via-ir
```

## Deploying

WIP

## User Flows

#### 1. <u>Entering into escrow</u>

A user enters into escrow by sending their MGD NFT (721 or 1155) to the escrow contract (MgdL2NFTEscrow.sol). You achieve this in several ways:  
 a) By making the user simply call any of the transfer functions from the NFT with the escrow contract as the destination or  
 b) by having the user sign an EIP712 message. The latter would be explained further in detail in another section.

Consequently, the "Transfer()" event is emitted from the corresponding nft contract, but in addition escrow contract emits:

```js
event EnterEscrow(
    address nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed voucherId
  );
```

The `voucherId` is a unique identifier that will help create the representation of the NFT on the L2.

**NOTE** All the information on the `EnterEscrow(...)` event is needed to create the L2 voucher.
**NOTE** Only MGD nfts are currently supported for escrow, all others will revert.

#### 2. <u>Receiving clearance notice to mint voucher on L2</u>

Once a user enters a NFT into escrow, the L2-bridge system is responsible to send a message to the voucher contract on the L2 (either 721 or 1155 as applicable) to give "clearance" to create the specific `voucherId`.
This will result in the L2-bridge system calling the method "setL1NftMintClearance(uint256 voucherId, bool state)" in contracts either Mgd721L2Voucher.sol or Mgd1155Voucher.sol and to emit the following:

```js
event L1NftMintClearance(uint256 indexed voucherId, bool state);
```

#### 3. <u>Minting a voucher</u>

Once clearance is set, a user or anyone else can call the method function `mintVoucherFromL1Nft(...)` in the corresponding voucher contract (721 or 1155). This will emit:

```js
L1NftMinted(voucherId);
```

Alternatively, if it is a native L2 voucher (meaning that the user is creating a new NFT directly on the L2 that does not have an Ethereum nft representation yet) a user shall call `mintNft(...)` from either Mgd721L2Voucher.sol or Mgd1155Voucher.sol. This will emit the same event used in the MGD's v2-contracts:

```js
event MintGoldDustNFTMinted(
    uint256 indexed voucherId,
    string tokenURI,
    address owner,
    uint256 royalty,
    uint256 amount,
    bool isERC721,
    uint256 collectorMintId,
    bytes memoir
  );
```

#### 4. <u>Starting the redeemption process</u>

At any point a user can decide to redeem their voucher and bring it to ethereum. This also applies to "L2 native vouchers". Which we can define them as a voucher that currently does not have an ethereum NFT representation.
To start the process a user will call the following method `redeemVoucherToL1(...)` from the applicable 721 or 1155 voucher contract.
**NOTE** The inputs for `redeemVoucherToL1` defer from the 721 and 1155 voucher contracts.
The voucher contract in L2 (either 721 or 1155) would then emit:

```js
event RedeemVoucher(
    uint256 indexed voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed releaseKey
  );
```

The `releaseKey` is a unique identifier that will help identify in the escrow contract what NFT can be released or created (in the case of a L2 native voucher).

**NOTE** All the information on the `RedeemVoucher(...)` event is needed to release the NFT from escrow on ethereum.

#### 5. <u>Receiving release clearance from the escrow</u>

The L2 bridge system receives a call when the redeemption process is started, and notifies the escrow contract on ethereum to give clearance for the `releaseKey` via the following method in the escrow contract: `setRedeemClearanceKey(uint256 key, bool state)`. Then the escrow contract emits:

```js
event RedeemClearanceKey(uint256 indexed key, bool state);

```

**NOTE** The process of releasing an NFT may take up to 7 days. However, MGD will explore ways to expedite such process.

#### 6. <u>Releasing from escrow</u>

Once clearance is given, the user can call in the escrow contract method `releaseFromEscrow(...)`. Then the escrow emits:

```js
event ReleasedEscrow(
    address indexed receiver,
    address nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 indexed voucherId,
    uint256 key
  );
```

Within the same transaction the ethereum Mgd NFT contracts also emit an event indicating that the market data (mainly handling primary sales) has been updated:

```js
event EscrowUpdateMarketData(uint256 indexed tokenId, MgdL1MarketData marketData);
```
