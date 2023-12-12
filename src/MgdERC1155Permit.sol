// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC1155} from "mgd-v2-contracts/MintGoldDustERC1155.sol";
import {MgdCompanyL2Sync, ICrossDomainMessenger} from "./MgdCompanyL2Sync.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title MgdERC1155Permit
 * @author
 * @notice This contracts extends the L1 {MintGoldDustERC115} contract
 * with functionality that allows to the use of Permit function
 * or signature to transfer an NFT.
 * @dev This contract should upgrade existing {MintGoldDustERC721}:
 * https://github.com/Mint-Gold-Dust/v2-contracts
 * This implementation is inspired by:
 * https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/ERC721Permit.sol
 */
contract MgdERC1155Permit is MintGoldDustERC1155 {
  // Events
  event SetAllowance(
    address indexed owner, address indexed spender, uint256 indexed id, uint256 amount
  );

  // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 private constant _TYPE_HASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

  // keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 amount,uint256 nonce,uint256 deadline)")
  bytes32 private constant _PERMIT_TYPEHASH =
    0x50d6fc6fbe2270eb4d3f1c10a4bff9c8ac65bd8e6af5305a9796cff2597cd7a5;

  // keccak("MgdERC1155Permit");
  bytes32 private constant _HASHED_NAME =
    0xf4ceb8e179a4c9d347b9b9cab99e860f3b7bada8c94797b777888a00c3c4bdc2;

  // keccak("v0.0.1");
  bytes32 private constant _HASHED_VERSION =
    0x6bda7e3f385e48841048390444cced5cc795af87758af67622e5f4f0882c4a99;

  // keccak256(abi.encodePacked(owner,tokenId)) => current nonce
  mapping(bytes32 => uint256) internal _nonces;

  // keccak256(abi.encodePacked(owner,spender,tokenId)) => amount
  mapping(bytes32 => uint256) internal _allowance;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ___gap;

  function getAllowance(
    address owner,
    address spender,
    uint256 tokenId
  )
    public
    view
    returns (uint256)
  {
    return _getAllowance(owner, spender, tokenId);
  }

  /**
   * @notice Allow `msg.sender` for `spender` to `transfer` `tokenId` `amount`.
   *
   * @param spender of allowance
   * @param tokenId to give allowance
   * @param amount to give allowance
   */
  function setAllowance(address spender, uint256 tokenId, uint256 amount) public returns (bool) {
    address owner = _msgSender();
    _setAllowance(owner, spender, tokenId, amount);
    return true;
  }

  /**
   *
   * @param owner of the `tokenId`
   * @param operator of this allowance
   * @param tokenId to give allowance
   * @param amount of `tokenId` to give allowance
   * @param deadline  of the `signature`
   * @param v value of signature
   * @param r value of signature
   * @param s value of signature
   */
  function permit(
    address owner,
    address operator,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
    payable
  {
    require(_blockTimestamp() <= deadline, "Permit expired");
    require(balanceOf(owner, tokenId) >= amount, "Invalid amount");
    require(operator != owner, "ERC1155Permit: approval to current owner");

    bytes32 digest = getPermitDigest(
      owner, operator, tokenId, amount, _getAndIncrementNonce(owner, tokenId), deadline
    );

    if (Address.isContract(owner)) {
      require(
        IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
        "Unauthorized"
      );
    } else {
      address recoveredAddress = ECDSA.recover(digest, v, r, s);
      require(recoveredAddress != address(0), "Invalid signature");
      require(recoveredAddress == owner, "Unauthorized");
    }

    _setAllowance(owner, operator, tokenId, amount);
  }

  /**
   * @notice Common entry external function for the `permit()` function.
   *
   * @param params abi.encoded inputs for this.permit() public
   */
  function permit(bytes calldata params) external payable {
    (
      address owner,
      address operator,
      uint256 tokenId,
      uint256 amount,
      uint256 deadline,
      uint8 v,
      bytes32 r,
      bytes32 s
    ) = abi.decode(params, (address, address, uint256, uint256, uint256, uint8, bytes32, bytes32));
    permit(owner, operator, tokenId, amount, deadline, v, r, s);
  }

  /**
   * @notice Transfers `amount` tokens of token type `id` from `from` to `to`.
   * Caller can spend their `_allowance` if they have it.
   * @dev Overriden to utilize the granular allowance system set up in this contract.
   * Requirements:
   * - If using allowance, `msg.sender` must == `to`.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  )
    public
    override
  {
    address operator = _msgSender();
    require(
      from == operator || isApprovedForAll(from, operator)
        || (_getAllowance(from, to, id) >= amount && operator == to),
      "ERC1155: caller is not owner or approved or has allowance"
    );
    if (from != operator && !isApprovedForAll(from, operator)) {
      _spendAllowance(from, to, id, amount);
    }
    _safeTransferFrom(from, to, id, amount, data);
  }

  function PERMIT_TYPEHASH() external pure returns (bytes32) {
    return _PERMIT_TYPEHASH;
  }

  function getPermitDigest(
    address owner,
    address spender,
    uint256 tokenId,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
  )
    public
    view
    returns (bytes32 digest)
  {
    bytes32 structHash =
      keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, tokenId, amount, nonce, deadline));
    digest = _hashTypedData(structHash);
  }

  function currentNonce(address owner, uint256 tokenId) public view returns (uint256 current) {
    current = _nonces[_hashedOwnerTokenID(owner, tokenId)];
  }

  function _getAllowance(
    address owner,
    address spender,
    uint256 tokenId
  )
    internal
    view
    returns (uint256 allowance)
  {
    allowance = _allowance[_hashedOwnerSpenderTokenID(owner, spender, tokenId)];
  }

  function _spendAllowance(address from, address to, uint256 tokenId, uint256 amount) internal {
    uint256 currentAllowance = _getAllowance(from, to, tokenId);
    if (currentAllowance != type(uint256).max) {
      require(currentAllowance >= amount, "ERC1155Permit: insufficient allowance");
      unchecked {
        _setAllowance(from, to, tokenId, currentAllowance - amount);
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
    isZeroAddress(owner)
    isZeroAddress(spender)
  {
    _allowance[_hashedOwnerSpenderTokenID(owner, spender, tokenId)] = amount;
    emit SetAllowance(owner, spender, tokenId, amount);
  }

  function _getAndIncrementNonce(address owner, uint256 tokenId) internal returns (uint256 current) {
    bytes32 hashed = _hashedOwnerTokenID(owner, tokenId);
    current = _nonces[hashed];
    _nonces[hashed] += 1;
  }

  function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _domainSeparator() private view returns (bytes32) {
    return
      keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
  }

  function _blockTimestamp() private view returns (uint256) {
    return block.timestamp;
  }

  function _hashedOwnerTokenID(address owner, uint256 tokenId) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(owner, tokenId));
  }

  function _hashedOwnerSpenderTokenID(
    address owner,
    address spender,
    uint256 tokenId
  )
    private
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked(owner, spender, tokenId));
  }
}
