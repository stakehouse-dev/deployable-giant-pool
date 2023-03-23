pragma solidity ^0.8.18;

// SPDX-License-Identifier: MIT

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingFundsVault {
    function batchDepositETHForStaking(bytes[] calldata _blsPublicKeyOfKnots, uint256[] calldata _amounts) external payable;
    function KnotAssociatedWithLPToken(address _token) external view returns (bytes memory);
    function burnLPTokensForETH(IERC20[] calldata _tokens, uint256[] calldata _amounts) external;
    function batchPreviewAccumulatedETH(address _user, IERC20[] calldata _token) external view returns (uint256);
    function claimRewards(address _recipient, bytes[] calldata _blsPubKeys) external;
}