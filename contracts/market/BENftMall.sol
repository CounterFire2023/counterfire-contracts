// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/HasSignature.sol";
import "../interfaces/IBEERC721.sol";
import "../utils/TimeChecker.sol";
import "./MallBase.sol";

contract BENftMall is MallBase, ReentrancyGuard, HasSignature, TimeChecker {
  using SafeERC20 for IERC20;

  constructor() HasSignature("NftMall", "1") {}

  mapping(address => bool) public nftTokenSupported;

  // Events
  event BuyTransaction(
    address indexed buyer,
    uint256 indexed nonce,
    uint256 tokenId,
    address[3] addresses,
    uint256 price
  );

  function addNFTTokenSupport(address nftToken) external onlyOwner {
    nftTokenSupported[nftToken] = true;
  }

  function removeNFTTokenSupport(address nftToken) external onlyOwner {
    nftTokenSupported[nftToken] = false;
  }

  function ignoreSignature(
    address[4] calldata addresses,
    uint256[] calldata signArray,
    bytes calldata signature
  ) external signatureValid(signature) {
    // address[4] [seller_address,nft_address,payment_token_address, buyer_address]
    // uint256[4] [token_id,price,salt_nonce,startTime]
    bytes32 criteriaMessageHash = getMessageHash(
      addresses[1],
      addresses[2],
      addresses[3],
      signArray
    );

    checkSigner(_msgSender(), criteriaMessageHash, signature);
    _useSignature(signature);
  }

  /**
   * @dev Function matched transaction with user signatures
   */
  function buyNFT(
    address[3] calldata addresses,
    uint256[4] calldata values,
    bytes calldata signature
  ) external nonReentrant signatureValid(signature) timeValid(values[3]) {
    // address[3] [seller_address,nft_address,payment_token_address]
    // uint256[4] [token_id,price,salt_nonce,startTime]
    // bytes seller_signature
    require(nftTokenSupported[addresses[1]], "BENftMall: Unsupported NFT");
    require(erc20Supported[addresses[2]], "BENftMall: invalid payment method");
    address to = _msgSender();

    uint256[] memory signArray = new uint256[](values.length);
    for (uint256 i = 0; i < values.length; ++i) {
      signArray[i] = values[i];
    }
    bytes32 criteriaMessageHash = getMessageHash(
      addresses[1],
      addresses[2],
      to,
      signArray
    );

    checkSigner(addresses[0], criteriaMessageHash, signature);
    // Check payment approval and buyer balance
    IERC20 paymentContract = IERC20(addresses[2]);
    require(
      paymentContract.balanceOf(to) >= values[1],
      "BENftMall: buyer doesn't have enough token to buy this item"
    );
    require(
      paymentContract.allowance(to, address(this)) >= values[1],
      "BENftMall: buyer doesn't approve marketplace to spend payment amount"
    );
    paymentContract.safeTransferFrom(to, feeToAddress, values[1]);

    // mint item to user
    IBEERC721 nft = IBEERC721(addresses[1]);
    nft.mint(to, values[0]);
    _useSignature(signature);
    // emit sale event
    emit BuyTransaction(to, values[2], values[0], addresses, values[1]);
  }

  function getMessageHash(
    address _nftAddress,
    address _tokenAddress,
    address _buyerAddress,
    uint256[] memory _datas
  ) public pure returns (bytes32) {
    bytes memory encoded = abi.encodePacked(
      _nftAddress,
      _tokenAddress,
      _buyerAddress
    );
    uint256 len = _datas.length;
    for (uint256 i = 0; i < len; ++i) {
      encoded = bytes.concat(encoded, abi.encodePacked(_datas[i]));
    }
    return keccak256(encoded);
  }
}
