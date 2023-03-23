pragma solidity ^0.8.18;

// SPDX-License-Identifier: MIT

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISavETHVault {
    function batchDepositETHForStaking(bytes[] calldata _blsPublicKeyOfKnots, uint256[] calldata _amounts) external payable;
    function KnotAssociatedWithLPToken(address _token) external view returns (bytes memory);
    function burnLPTokens(IERC20[] calldata _tokens, uint256[] calldata _amounts) external;
    function isDETHReadyForWithdrawal(address _lpTokenAddress) external view returns (bool);
}