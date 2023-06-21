// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/HasSignature.sol";
import "../interfaces/IBEERC1155.sol";
import "../interfaces/IAsset.sol";
import "../utils/TimeChecker.sol";
import "../utils/UInt.sol";
import "./MallBase.sol";

contract BENftMall is MallBase, ReentrancyGuard, HasSignature, TimeChecker {
  using SafeERC20 for IERC20;
  using UInt for uint256;

  constructor() HasSignature("NftMall", "1") {}

  mapping(address => bool) public erc721Supported;
  mapping(address => bool) public erc1155Supported;

  // Events
  event BuyTransaction(
    address indexed buyer,
    uint256 indexed orderId,
    address currency,
    uint256 price,
    address[] nftAddresses,
    uint256[] ids,
    uint256[] amounts
  );

  event AddNFTSuppout(address nftToken);
  event RemoveNFTSuppout(address nftToken);

  /**
   * @dev Add ERC20 support
   */
  function addERC721Support(address nftToken) external onlyOwner {
    erc721Supported[nftToken] = true;
    emit AddNFTSuppout(nftToken);
  }

  /**
   * @dev Remove 721 NFT support
   */
  function removeERC721Support(address nftToken) external onlyOwner {
    erc721Supported[nftToken] = false;
    emit RemoveNFTSuppout(nftToken);
  }

  /**
   * @dev Add 1155 NFT support
   */
  function addERC1155Support(address nftToken) external onlyOwner {
    erc1155Supported[nftToken] = true;
    emit AddNFTSuppout(nftToken);
  }

  /**
   * @dev Remove 1155 NFT support
   */
  function removeERC1155Support(address nftToken) external onlyOwner {
    erc1155Supported[nftToken] = false;
    emit RemoveNFTSuppout(nftToken);
  }

  /**
   * @dev Buy NFT and other Game item from mall
   */
  function buyNFT(
    address currency,
    address[] memory nftAddresses,
    uint256[] memory ids,
    uint256[] memory amounts,
    uint256[] memory values, // [orderId, price, startTime, saltNonce]
    bytes calldata signature
  ) external nonReentrant signatureValid(signature) timeValid(values[2]) {
    require(erc20Supported[currency], "BENftMall: invalid payment method");
    require(values.length == 4, "BENftMall: invalid values length");
    require(
      nftAddresses.length == ids.length && ids.length == amounts.length,
      "BENftMall: nftAddresses, ids and amounts length mismatch"
    );

    require(nftAddresses.length > 0, "BENftMall: ids length is zero");
    for (uint256 i = 0; i < nftAddresses.length; ++i) {
      require(
        erc721Supported[nftAddresses[i]] || erc1155Supported[nftAddresses[i]],
        "BENftMall: nft token is not supported"
      );
    }
    uint256[] memory signArray = new uint256[](ids.length * 2 + 4);
    for (uint256 i = 0; i < nftAddresses.length; ++i) {
      signArray[i * 2] = ids[i];
      signArray[i * 2 + 1] = amounts[i];
    }
    for (uint256 i = 0; i < values.length; ++i) {
      signArray[ids.length * 2 + i] = values[i];
    }
    bytes32 criteriaMessageHash = getMessageHash(
      currency,
      _msgSender(),
      nftAddresses,
      signArray
    );

    checkSigner(executor, criteriaMessageHash, signature);
    // Check payment approval and buyer balance
    require(
      IERC20(currency).balanceOf(_msgSender()) >= values[1],
      "BENftMall: buyer doesn't have enough token to buy this item"
    );
    require(
      IERC20(currency).allowance(_msgSender(), address(this)) >= values[1],
      "BENftMall: buyer doesn't approve enough token to buy this item"
    );

    // Transfer payment to seller
    IERC20(currency).safeTransferFrom(_msgSender(), feeToAddress, values[1]);
    for (uint256 i = 0; i < nftAddresses.length; ++i) {
      if (erc721Supported[nftAddresses[i]]) {
        IAsset(nftAddresses[i]).batchMint(
          _msgSender(),
          ids[i].asSingletonArray()
        );
      } else if (erc1155Supported[nftAddresses[i]]) {
        IBEERC1155(nftAddresses[i]).mintBatch(
          _msgSender(),
          ids[i].asSingletonArray(),
          amounts[i].asSingletonArray(),
          ""
        );
      }
    }
    _useSignature(signature);
    // emit buy event
    emit BuyTransaction(
      _msgSender(),
      values[0],
      currency,
      values[1],
      nftAddresses,
      ids,
      amounts
    );
  }

  function getMessageHash(
    address _tokenAddress,
    address _buyerAddress,
    address[] memory _nftAddresses,
    uint256[] memory _datas
  ) public pure returns (bytes32) {
    bytes memory encoded = abi.encodePacked(_tokenAddress, _buyerAddress);

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      encoded = bytes.concat(encoded, abi.encodePacked(_nftAddresses[i]));
    }

    for (uint256 i = 0; i < _datas.length; ++i) {
      encoded = bytes.concat(encoded, abi.encodePacked(_datas[i]));
    }
    return keccak256(encoded);
  }
}
