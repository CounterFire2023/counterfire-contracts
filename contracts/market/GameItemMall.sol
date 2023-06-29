// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/HasSignature.sol";
import "../utils/TimeChecker.sol";
import "./MallBase.sol";

/**
 *  @title GameItemMall
 *  @dev GameItemMall is a contract for managing centralized game items sale,
 *  allowing users to buy item in game.
 */
contract GameItemMall is MallBase, ReentrancyGuard, HasSignature, TimeChecker {
  using SafeERC20 for IERC20;

  mapping(uint256 => address) public orderIdUsed;

  event ItemSoldOut(
    address indexed buyer,
    uint256 indexed orderId,
    address currency,
    uint256 price
  );

  function buy(
    uint256 orderId,
    address currency,
    uint256 price,
    uint256 startTime,
    uint256 saltNonce,
    bytes calldata signature
  ) external nonReentrant signatureValid(signature) timeValid(startTime) {
    // check if orderId is used
    require(orderIdUsed[orderId] == address(0), "orderId is used");
    // check if currency is supported
    require(erc20Supported[currency], "currency is not supported");
    // check if price is valid
    require(price > 0, "price is zero");
    address buyer = _msgSender();
    bytes32 criteriaMessageHash = getMessageHash(
      buyer,
      orderId,
      currency,
      price,
      startTime,
      saltNonce
    );
    checkSigner(executor, criteriaMessageHash, signature);
    IERC20 paymentContract = IERC20(currency);
    require(
      paymentContract.balanceOf(buyer) >= price,
      "GameItemMall: buyer doesn't have enough token to buy this item"
    );
    require(
      paymentContract.allowance(buyer, address(this)) >= price,
      "GameItemMall: buyer doesn't approve marketplace to spend payment amount"
    );
    paymentContract.safeTransferFrom(_msgSender(), feeToAddress, price);
    orderIdUsed[orderId] = buyer;
    _useSignature(signature);

    emit ItemSoldOut(buyer, orderId, currency, price);
  }

  function getMessageHash(
    address _buyer,
    uint256 _orderId,
    address _currency,
    uint256 _price,
    uint256 _startTime,
    uint256 _saltNonce
  ) public pure returns (bytes32) {
    bytes memory encoded = abi.encodePacked(
      _buyer,
      _orderId,
      _currency,
      _price,
      _startTime,
      _saltNonce
    );
    return keccak256(encoded);
  }
}
