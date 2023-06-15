// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../core/HasSignature.sol";
import "../utils/TimeChecker.sol";
import "./MallBase.sol";

/**
 *  @title GameItemMarket
 *  @dev GameItemMarket is a contract for users sell item in game.
 */
contract GameItemMarket is
  MallBase,
  ReentrancyGuard,
  HasSignature,
  TimeChecker
{
  using SafeERC20 for IERC20;

  mapping(uint256 => address) public orderIdUsed;

  uint256 constant ROUND = 1000000;
  uint256 public transactionFee = (3 * ROUND) / 100; // 3%
  // min transaction fee is: 0
  uint256 public constant MIN_TRANSACTION_FEE = 0;
  // max transaction fee is: 10%
  uint256 public constant MAX_TRANSACTION_FEE = (10 * ROUND) / 100;

  constructor() HasSignature("GameItemMarket", "1") {}

  event ItemSoldOut(
    address indexed buyer,
    address indexed seller,
    uint256 indexed orderId,
    address currency,
    uint256 price
  );

  function buy(
    uint256 orderId,
    address seller,
    address currency,
    uint256 price,
    uint256 startTime,
    uint256 saltNonce,
    bytes calldata signature
  ) external nonReentrant signatureValid(signature) timeValid(startTime) {
    // check if orderId is used
    require(
      orderIdUsed[orderId] == address(0),
      "GameItemMarket: orderId is used"
    );
    // check if currency is supported
    require(
      erc20Supported[currency],
      "GameItemMarket: currency is not supported"
    );
    // check if price is valid
    require(price > 0, "GameItemMarket: price is zero");
    bytes32 criteriaMessageHash = getMessageHash(
      _msgSender(),
      seller,
      orderId,
      currency,
      price,
      feeToAddress,
      startTime,
      saltNonce
    );
    checkSigner(executor, criteriaMessageHash, signature);
    require(
      IERC20(currency).balanceOf(_msgSender()) >= price,
      "GameItemMall: buyer doesn't have enough token to buy this item"
    );
    require(
      IERC20(currency).allowance(_msgSender(), address(this)) >= price,
      "GameItemMall: buyer doesn't approve marketplace to spend payment amount"
    );
    uint256 _transactionFee = (price * transactionFee) / ROUND;
    if (_transactionFee > 0) {
      IERC20(currency).safeTransferFrom(
        _msgSender(),
        feeToAddress,
        _transactionFee
      );
    }
    IERC20(currency).safeTransferFrom(
      _msgSender(),
      seller,
      price - _transactionFee
    );
    orderIdUsed[orderId] = _msgSender();
    _useSignature(signature);

    emit ItemSoldOut(_msgSender(), seller, orderId, currency, price);
  }

  function setTransactionFee(uint256 _transactionFee) external onlyOwner {
    require(
      _transactionFee >= MIN_TRANSACTION_FEE &&
        _transactionFee <= MAX_TRANSACTION_FEE,
      "GameItemMarket: _transactionFee must >= 0 and <= 10%"
    );
    transactionFee = _transactionFee;
  }

  function getMessageHash(
    address _buyer,
    address _seller,
    uint256 _orderId,
    address _currency,
    uint256 _price,
    address _feeToAddress,
    uint256 _startTime,
    uint256 _saltNonce
  ) public pure returns (bytes32) {
    bytes memory encoded = abi.encodePacked(
      _buyer,
      _seller,
      _orderId,
      _currency,
      _price,
      _feeToAddress,
      _startTime,
      _saltNonce
    );
    return keccak256(encoded);
  }
}
