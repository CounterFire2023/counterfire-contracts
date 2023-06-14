// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FT is ERC20, ERC20Burnable, Pausable, AccessControl {
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  uint256 public immutable supplyLimit;

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 _supplyLimt
  ) ERC20(name_, symbol_) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
    supplyLimit = _supplyLimt;
  }

  // constructor() ERC20("BE test USDT", "USDT") {}

  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    if (supplyLimit > 0) {
      require(
        (totalSupply() + amount) <= supplyLimit,
        "Exceed the total supply"
      );
    }
    _mint(to, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  function setPauserRole(address to) external {
    grantRole(PAUSER_ROLE, to);
  }

  function removePauserRole(address to) external {
    revokeRole(PAUSER_ROLE, to);
  }

  function setMintRole(address to) external {
    grantRole(MINTER_ROLE, to);
  }

  function removeMintRole(address to) external {
    revokeRole(MINTER_ROLE, to);
  }
}
