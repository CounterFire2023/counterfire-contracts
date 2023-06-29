// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BENftMarket is Ownable, ReentrancyGuard, ERC1155Holder, ERC721Holder {
  using SafeERC20 for IERC20;

  struct OrderInfo {
    uint256 orderId;
    uint256 tokenId;
    uint256 amount;
    address owner;
    uint256 price;
    address nftToken;
    address currency;
  }
  mapping(address => bool) public erc721Supported;
  mapping(address => bool) public erc1155Supported;
  mapping(address => bool) public erc721SupportedHistory;
  mapping(address => bool) public erc1155SupportedHistory;
  mapping(address => bool) public erc20Supported;
  mapping(uint256 => OrderInfo) public orderInfos;
  mapping(address => uint256) public nftPriceMaxLimit;
  mapping(address => uint256) public nftPriceMinLimit;

  event SellOrder(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed nftToken,
    uint256 amount,
    uint256 orderId,
    address currency,
    uint256 price
  );

  event CancelOrder(
    uint256 indexed orderId,
    address indexed nftToken,
    uint256 indexed tokenId
  );

  event PriceUpdate(
    uint256 indexed orderId,
    address indexed nftToken,
    uint256 indexed tokenId,
    uint256 priceOld,
    uint256 price
  );

  event BuyOrder(
    uint256 indexed tokenId,
    uint256 orderId,
    address nftToken,
    uint256 amount,
    address seller,
    address buyer,
    address erc20,
    uint256 price
  );

  event AddNFTSuppout(address nftToken);
  event RemoveNFTSuppout(address nftToken);
  event AddERC20Suppout(address erc20);
  event RemoveERC20Suppout(address erc20);

  uint256 public tranFeeTotal;
  uint256 public tranTaxTotal;

  uint256 constant ROUND = 1000000;
  uint256 public transactionFee = (3 * ROUND) / 100;
  // min transaction fee is: 0
  uint256 public constant MIN_TRANSACTION_FEE = 0;
  // max transaction fee is: 10%
  uint256 public constant MAX_TRANSACTION_FEE = (10 * ROUND) / 100;

  uint256 public transactionTax = (1 * ROUND) / 100;
  // min transaction tax is: 0
  uint256 public constant MIN_TRANSACTION_TAX = 0;
  // max transaction tax is: 10%
  uint256 public constant MAX_TRANSACTION_TAX = (10 * ROUND) / 100;

  address public feeToAddress;

  address public taxToAddress;

  uint256 public incrId;

  function sell(
    address nftToken,
    address currency,
    uint256 tokenId,
    uint256 price,
    uint256 amount
  ) external {
    require(tokenId != 0, "NFTMarket: tokenId can not be 0!");
    require(
      erc721Supported[nftToken] || erc1155Supported[nftToken],
      "NFTMarket: Unsupported NFT"
    );
    require(erc20Supported[currency], "NFTMarket: Unsupported tokens");
    require(
      price <= nftPriceMaxLimit[nftToken] || nftPriceMaxLimit[nftToken] == 0,
      "NFTMarket: Maximum price limit exceeded"
    );
    require(
      price >= nftPriceMinLimit[nftToken],
      "NFTMarket: Below the minimum price limit"
    );
    incrId += 1;
    OrderInfo storage orderInfo = orderInfos[incrId];
    orderInfo.orderId = incrId;
    orderInfo.tokenId = tokenId;
    orderInfo.amount = amount;
    orderInfo.nftToken = nftToken;
    orderInfo.owner = _msgSender();
    orderInfo.price = price;
    orderInfo.currency = currency;
    if (erc721Supported[nftToken]) {
      require(amount == 1, "NFTMarket: ERC721 amount must be 1 ");
      IERC721(nftToken).safeTransferFrom(_msgSender(), address(this), tokenId);
    } else if (erc1155Supported[nftToken]) {
      IERC1155(nftToken).safeTransferFrom(
        _msgSender(),
        address(this),
        tokenId,
        amount,
        ""
      );
    }

    emit SellOrder(
      tokenId,
      _msgSender(),
      nftToken,
      amount,
      incrId,
      currency,
      price
    );
  }

  function buy(uint256 orderId, uint256 price) external nonReentrant {
    require(orderId > 0 && orderId <= incrId, "NFTMarket: orderId error");
    OrderInfo memory orderInfo = orderInfos[orderId];
    require(orderInfo.orderId != 0, "NFTMarket: order info does not exist");
    require(orderInfo.price == price, "NFTMarket: Price error");
    uint256 _transactionFee = (orderInfo.price * transactionFee) / ROUND;
    tranFeeTotal = tranFeeTotal + _transactionFee;
    uint256 _transactionTax = (orderInfo.price * transactionTax) / ROUND;
    tranTaxTotal = tranTaxTotal + _transactionTax;
    uint256 _amount = orderInfo.price - _transactionFee - _transactionTax;
    IERC20 paymentContract = IERC20(orderInfo.currency);
    require(
      paymentContract.balanceOf(_msgSender()) >= orderInfo.price,
      "BENFTMarket: buyer doesn't have enough token to buy this item"
    );
    require(
      paymentContract.allowance(_msgSender(), address(this)) >= orderInfo.price,
      "BENFTMarket: buyer doesn't approve marketplace to spend payment amount"
    );
    paymentContract.safeTransferFrom(_msgSender(), orderInfo.owner, _amount);
    if (_transactionFee > 0) {
      paymentContract.safeTransferFrom(
        _msgSender(),
        feeToAddress,
        _transactionFee
      );
    }
    if (_transactionTax > 0) {
      paymentContract.safeTransferFrom(
        _msgSender(),
        taxToAddress,
        _transactionTax
      );
    }

    if (
      erc721Supported[orderInfo.nftToken] ||
      erc721SupportedHistory[orderInfo.nftToken]
    ) {
      IERC721(orderInfo.nftToken).safeTransferFrom(
        address(this),
        _msgSender(),
        orderInfo.tokenId
      );
    } else if (
      erc1155Supported[orderInfo.nftToken] ||
      erc1155SupportedHistory[orderInfo.nftToken]
    ) {
      IERC1155(orderInfo.nftToken).safeTransferFrom(
        address(this),
        _msgSender(),
        orderInfo.tokenId,
        orderInfo.amount,
        ""
      );
    }

    emit BuyOrder(
      orderInfo.tokenId,
      orderId,
      orderInfo.nftToken,
      orderInfo.amount,
      orderInfo.owner,
      _msgSender(),
      orderInfo.currency,
      orderInfo.price
    );
    delete orderInfos[orderId];
  }

  function cancelOrder(uint256 orderId) external nonReentrant {
    require(orderId > 0 && orderId <= incrId, "NFTMarket: orderId error");
    OrderInfo memory orderInfo = orderInfos[orderId];
    require(orderInfo.orderId != 0, "NFTMarket: NFT does not exist");
    require(orderInfo.owner == _msgSender(), "NFTMarket: caller is not owner");
    if (
      erc721Supported[orderInfo.nftToken] ||
      erc721SupportedHistory[orderInfo.nftToken]
    ) {
      IERC721(orderInfo.nftToken).safeTransferFrom(
        address(this),
        _msgSender(),
        orderInfo.tokenId
      );
    } else if (
      erc1155Supported[orderInfo.nftToken] ||
      erc1155SupportedHistory[orderInfo.nftToken]
    ) {
      IERC1155(orderInfo.nftToken).safeTransferFrom(
        address(this),
        _msgSender(),
        orderInfo.tokenId,
        orderInfo.amount,
        ""
      );
    }
    delete orderInfos[orderId];

    emit CancelOrder(orderId, orderInfo.nftToken, orderInfo.tokenId);
  }

  function updatePrice(uint256 orderId, uint256 price) external {
    require(orderId > 0 && orderId <= incrId, "NFTMarket: orderId error");
    OrderInfo storage orderInfo = orderInfos[orderId];
    require(orderInfo.orderId != 0, "NFTMarket: NFT does not exist");
    require(orderInfo.owner == _msgSender(), "NFTMarket: caller is not owner");
    require(
      price <= nftPriceMaxLimit[orderInfo.nftToken] ||
        nftPriceMaxLimit[orderInfo.nftToken] == 0,
      "NFTMarket: Maximum price limit exceeded"
    );
    require(
      price >= nftPriceMinLimit[orderInfo.nftToken],
      "NFTMarket: Below the minimum price limit"
    );
    uint256 priceOld = orderInfo.price;
    orderInfo.price = price;
    emit PriceUpdate(
      orderId,
      orderInfo.nftToken,
      orderInfo.tokenId,
      priceOld,
      price
    );
  }

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
    erc721SupportedHistory[nftToken] = true;
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
    erc1155SupportedHistory[nftToken] = true;
    emit RemoveNFTSuppout(nftToken);
  }

  /**
   * @dev Add ERC20 support
   */
  function addERC20Support(address erc20) external onlyOwner {
    require(erc20 != address(0), "NFTMarket: ERC20 address is zero");
    erc20Supported[erc20] = true;
    emit AddERC20Suppout(erc20);
  }

  /**
   * @dev Remove ERC20 support
   */
  function removeERC20Support(address erc20) external onlyOwner {
    erc20Supported[erc20] = false;
    emit RemoveERC20Suppout(erc20);
  }

  /**
   * @dev Set the maximum price limit for NFT
   */
  function setNFTPriceMaxLimit(
    address nftToken,
    uint256 maxLimit
  ) external onlyOwner {
    require(
      maxLimit >= nftPriceMinLimit[nftToken],
      "NFTMarket: maxLimit can not be less than min limit!"
    );
    nftPriceMaxLimit[nftToken] = maxLimit;
  }

  /**
   * @dev Set the minimum price limit for NFT
   */
  function setNFTPriceMinLimit(
    address nftToken,
    uint256 minLimit
  ) external onlyOwner {
    if (nftPriceMaxLimit[nftToken] != 0) {
      require(
        minLimit <= nftPriceMaxLimit[nftToken],
        "NFTMarket: minLimit can not be larger than max limit!"
      );
    }
    nftPriceMinLimit[nftToken] = minLimit;
  }

  /**
   * @dev Set the transaction fee
   */
  function setTransactionFee(uint256 _transactionFee) external onlyOwner {
    require(
      _transactionFee >= MIN_TRANSACTION_FEE &&
        _transactionFee <= MAX_TRANSACTION_FEE,
      "NFTMarket: _transactionFee must >= 0 and <= 10%"
    );
    transactionFee = _transactionFee;
  }

  /**
   * @dev Set the fee received address
   */
  function setFeeToAddress(address _feeToAddress) external onlyOwner {
    require(
      _feeToAddress != address(0),
      "NFTMarket: fee received address can not be zero"
    );
    feeToAddress = _feeToAddress;
  }

  /**
   * @dev Set the transaction tax
   */
  function setTransactionTax(uint256 _transactionTax) external onlyOwner {
    require(
      _transactionTax >= MIN_TRANSACTION_TAX &&
        _transactionTax <= MAX_TRANSACTION_TAX,
      "NFTMarket: _transactionTax must >= 0 and <= 10%"
    );
    transactionTax = _transactionTax;
  }

  /**
   * @dev Set the tax received address
   */
  function setTaxToAddress(address _taxToAddress) external onlyOwner {
    require(
      _taxToAddress != address(0),
      "NFTMarket: tax received address can not be zero"
    );
    taxToAddress = _taxToAddress;
  }
}
