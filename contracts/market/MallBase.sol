// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MallBase is Ownable {
  address public executor;
  // Address to receive transaction fee
  address public feeToAddress;

  mapping(address => bool) public erc20Supported;
  event AddERC20Suppout(address erc20);
  event RemoveERC20Suppout(address erc20);

  function addERC20Support(address erc20) external onlyOwner {
    require(erc20 != address(0), "ERC20 address is zero");
    erc20Supported[erc20] = true;
    emit AddERC20Suppout(erc20);
  }

  function removeERC20Support(address erc20) external onlyOwner {
    erc20Supported[erc20] = false;
    emit RemoveERC20Suppout(erc20);
  }

  /**
   * @dev update executor
   */
  function updateExecutor(address account) external onlyOwner {
    require(account != address(0), "address can not be zero");
    executor = account;
  }

  function setFeeToAddress(address _feeToAddress) external onlyOwner {
    require(
      _feeToAddress != address(0),
      "fee received address can not be zero"
    );
    feeToAddress = _feeToAddress;
  }
}
