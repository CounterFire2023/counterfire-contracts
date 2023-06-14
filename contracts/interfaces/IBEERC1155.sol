// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBEERC1155 is IERC1155 {
  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external;

  function burnBatch(
    address owner,
    uint256[] memory ids,
    uint256[] memory values
  ) external;

  function balanceOf(address account, uint256 id)
    external
    view
    returns (uint256);

  function canMint(uint256 id) external view returns (bool);

  function isLocked(uint256 id) external view returns (bool);
  
}
