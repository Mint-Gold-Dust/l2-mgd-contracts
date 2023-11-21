// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface ISafe {
  function isOwner(address account) external view returns (bool);
  function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
}

contract SafeAccountChecker {
  mapping(address => bool) private _implementations;

  constructor() {
    _implementations[0x41675C099F32341bf84BFc5382aF534df5C7461a] = true; // v1.4.1
    _implementations[0x29fcB43b46531BcA003ddC8FCB67FFE91900C762] = true; // L2 v1.4.1
    _implementations[0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552] = true; // v1.3.0
    _implementations[0x69f4D1788e39c87893C980c06EdF4b7f686e2938] = true; // v1.3.0
    _implementations[0x3E5c63644E683549055b9Be8653de26E0B4CD36E] = true; // L2 v1.3.0
    _implementations[0xfb1bffC9d739B8D520DaF37dF666da4C687191EA] = true; // L2 v1.3.0
    _implementations[0x6851D6fDFAfD08c0295C392436245E5bc78B0185] = true; // v1.2.0
    _implementations[0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F] = true; // v1.1.0
    _implementations[0xb6029EA3B2c51D09a50B53CA8012FeEB05bDa35A] = true; // v1.0.0
  }

  function isAddressASafe(address account) public view returns (bool) {
    try ISafe(account).getStorageAt(0, 1) returns (bytes memory response) {
      address implementation = _castBytesToAddress(response);
      return _implementations[implementation];
    } catch {
      return false;
    }
  }

  function isAccountOwnerInSafe(address account, address safe) public view returns (bool) {
    return ISafe(safe).isOwner(account);
  }

  function _castBytesToAddress(bytes memory data) private pure returns (address addr) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      addr := mload(add(data, 32))
    }
  }
}
