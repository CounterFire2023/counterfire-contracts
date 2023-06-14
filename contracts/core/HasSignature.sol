// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HasSignature is Ownable {
  bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
  uint256 private immutable _CACHED_CHAIN_ID;
  address private immutable _CACHED_THIS;

  bytes32 private immutable _HASHED_NAME;
  bytes32 private immutable _HASHED_VERSION;
  bytes32 private immutable _TYPE_HASH;
  mapping(bytes => bool) private _usedSignatures;

  constructor(string memory name, string memory version) {
    bytes32 hashedName = keccak256(bytes(name));
    bytes32 hashedVersion = keccak256(bytes(version));
    bytes32 typeHash = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    _HASHED_NAME = hashedName;
    _HASHED_VERSION = hashedVersion;
    _CACHED_CHAIN_ID = block.chainid;
    _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
      typeHash,
      hashedName,
      hashedVersion
    );
    _CACHED_THIS = address(this);
    _TYPE_HASH = typeHash;
  }

  function _buildDomainSeparator(
    bytes32 typeHash,
    bytes32 nameHash,
    bytes32 versionHash
  ) private view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          typeHash,
          nameHash,
          versionHash,
          block.chainid,
          address(this)
        )
      );
  }

  /**
   * @dev Returns the domain separator for the current chain.
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    if (address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID) {
      return _CACHED_DOMAIN_SEPARATOR;
    } else {
      return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
    }
  }

  /**
   * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
   * function returns the hash of the fully encoded EIP712 message for this domain.
   *
   * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
   *
   * ```solidity
   * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
   *     keccak256("Mail(address to,string contents)"),
   *     mailTo,
   *     keccak256(bytes(mailContents))
   * )));
   * address signer = ECDSA.recover(digest, signature);
   * ```
   */
  function _hashTypedDataV4(
    bytes32 structHash
  ) internal view virtual returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
  }

  function checkSigner712(
    address signer,
    bytes32 structHash,
    bytes memory signature
  ) public view {
    require(signer != address(0), "[BE] invalid signer");
    bytes32 digest = _hashTypedDataV4(structHash);
    address recovered = ECDSA.recover(digest, signature);
    require(recovered == signer, "[BE] invalid signature");
  }

  function checkSigner(
    address signer,
    bytes32 hash,
    bytes memory signature
  ) public pure {
    require(signer != address(0), "[BE] invalid signer");
    require(signature.length == 65, "[BE] invalid signature length");
    bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);

    address recovered = ECDSA.recover(ethSignedMessageHash, signature);
    require(recovered == signer, "[BE] invalid signature");
  }

  modifier signatureValid(bytes calldata signature) {
    require(
      !_usedSignatures[signature],
      "[BE] signature used. please send another transaction with new signature"
    );
    _;
  }

  function _useSignature(bytes calldata signature) internal {
    if (!_usedSignatures[signature]) {
      _usedSignatures[signature] = true;
    }
  }
}
