pragma solidity ^0.8.18;

// SPDX-License-Identifier: BUSL-1.1

import { StakehouseAPI } from "@blockswaplab/stakehouse-solidity-api/contracts/StakehouseAPI.sol";
import { GiantLP } from "./GiantLP.sol";
import { ISavETHVault } from "./interfaces/ISavETHVault.sol";
import { GiantPoolBase } from "./GiantPoolBase.sol";
import { Errors } from "./Errors.sol";
import { GiantLPDeployer } from "./GiantLPDeployer.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error ContractPaused();

/// @notice A giant pool that can provide protected deposit liquidity to any liquid staking network
contract GiantSavETHVaultPool is StakehouseAPI, GiantPoolBase, UUPSUpgradeable, PausableUpgradeable {

    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Emitted when giant LP is burnt to receive dETH
    event LPBurnedForDETH(address indexed savETHVaultLPToken, address indexed sender, uint256 amount);

    /// @notice Associated fees and mev pool address
    address public feesAndMevGiantPool;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function init(
        address _lpDeployer,
        address _feesAndMevGiantPool,
        address _upgradeManager
    ) external virtual initializer {
        _init(_lpDeployer, _feesAndMevGiantPool, _upgradeManager);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /// @dev Owner based upgrades
    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    /// @notice Allow the contract owner to trigger pausing of core features
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Allow the contract owner to trigger unpausing of core features
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Given the liquidity of the giant pool, stake ETH to receive protected deposits from many liquid staking networks (LSDNs)
    /// @dev Take ETH from the contract balance in order to send money to the individual vaults
    /// @param _savETHVaults List of savETH vaults that belong to individual liquid staking derivative networks
    /// @param _ETHTransactionAmounts ETH being attached to each savETH vault in the list
    /// @param _blsPublicKeys For every savETH vault, the list of BLS keys of LSDN validators receiving funding
    /// @param _stakeAmounts For every savETH vault, the amount of ETH each BLS key will receive in funding
    function batchDepositETHForStaking(
        address[] calldata _savETHVaults,
        uint256[] calldata _ETHTransactionAmounts,
        bytes[][] calldata _blsPublicKeys,
        uint256[][] calldata _stakeAmounts
    ) public whenContractNotPaused nonReentrant onlyOwner {
        uint256 numOfSavETHVaults = _savETHVaults.length;
        if (numOfSavETHVaults == 0) revert Errors.EmptyArray();
        if (numOfSavETHVaults != _ETHTransactionAmounts.length) revert Errors.InconsistentArrayLength();
        if (numOfSavETHVaults != _blsPublicKeys.length) revert Errors.InconsistentArrayLength();
        if (numOfSavETHVaults != _stakeAmounts.length) revert Errors.InconsistentArrayLength();

        // For every vault specified, supply ETH from the giant pool to the savETH pool of each BLS key
        for (uint256 i; i < numOfSavETHVaults; ++i) {
            uint256 transactionAmount = _ETHTransactionAmounts[i];

            // As ETH is being deployed to a savETH pool vault, it is no longer idle
            idleETH -= transactionAmount;

            // Deposit ETH for staking of BLS key
            ISavETHVault(_savETHVaults[i]).batchDepositETHForStaking{ value: transactionAmount }(
                _blsPublicKeys[i],
                _stakeAmounts[i]
            );

            uint256 numOfPublicKeys = _blsPublicKeys[i].length;
            for (uint256 j; j < numOfPublicKeys; ++j) {
                // because of withdrawal batch allocation, partial funding amounts would add too much complexity for later allocation
                if (_stakeAmounts[i][j] != 24 ether) revert Errors.InvalidAmount();
                _onStake(_blsPublicKeys[i][j]);
                isBLSPubKeyFundedByGiantPool[_blsPublicKeys[i][j]] = true;
            }
        }
    }

    /// @notice Allow a user to burn their giant LP in exchange for dETH that is ready to withdraw from a set of savETH vaults
    /// @param _savETHVaults List of savETH vaults being interacted with
    /// @param _lpTokens List of savETH vault LP being burnt from the giant pool in exchange for dETH
    /// @param _amounts Amounts of giant LP the user owns which is burnt 1:1 with savETH vault LP and in turn that will give a share of dETH
    function withdrawDETH(
        address[] calldata _savETHVaults,
        IERC20[][] calldata _lpTokens,
        uint256[][] calldata _amounts
    ) external whenContractNotPaused nonReentrant {
        uint256 numOfVaults = _savETHVaults.length;
        if (numOfVaults == 0) revert Errors.EmptyArray();
        if (numOfVaults != _lpTokens.length) revert Errors.InconsistentArrayLength();
        if (numOfVaults != _amounts.length) revert Errors.InconsistentArrayLength();

        // Firstly capture current dETH balance and see how much has been deposited after the loop
        uint256 dETHReceivedFromAllSavETHVaults = getDETH().balanceOf(address(this));
        for (uint256 i; i < numOfVaults; ++i) {
            ISavETHVault vault = ISavETHVault(_savETHVaults[i]);

            // Simultaneously check the status of LP tokens held by the vault and the giant LP balance of the user
            uint256 numOfTokens = _lpTokens[i].length;
            for (uint256 j; j < numOfTokens; ++j) {
                IERC20 token = _lpTokens[i][j];
                uint256 amount = _amounts[i][j];

                // Check the user has enough giant LP to burn and that the pool has enough savETH vault LP
                _assertUserHasEnoughGiantLPToClaimVaultLP(token, amount);

                // Magic - check user is part of the correct withdrawal batch
                uint256 allocatedWithdrawalBatch = allocatedWithdrawalBatchForBlsPubKey[vault.KnotAssociatedWithLPToken(address(token))];
                _reduceUserAmountFundedInBatch(allocatedWithdrawalBatch, msg.sender, amount);

                // Burn giant LP from user before sending them dETH
                lpTokenETH.burn(msg.sender, amount);

                emit LPBurnedForDETH(address(token), msg.sender, amount);
            }

            // Withdraw dETH from specific LSD network
            vault.burnLPTokens(_lpTokens[i], _amounts[i]);
        }

        // Calculate how much dETH has been received from burning
        dETHReceivedFromAllSavETHVaults = getDETH().balanceOf(address(this)) - dETHReceivedFromAllSavETHVaults;

        // Send giant LP holder dETH owed
        getDETH().transfer(msg.sender, dETHReceivedFromAllSavETHVaults);
    }

    /// @notice Any ETH that has not been utilized by a savETH vault can be brought back into the giant pool
    /// @param _savETHVaults List of savETH vaults where ETH is staked
    /// @param _lpTokens List of LP tokens that the giant pool holds which represents ETH in a savETH vault
    /// @param _amounts Amounts of LP within the giant pool being burnt
    function bringUnusedETHBackIntoGiantPool(
        address[] calldata _savETHVaults,
        IERC20[][] calldata _lpTokens,
        uint256[][] calldata _amounts
    ) external whenContractNotPaused nonReentrant {
        uint256 numOfVaults = _savETHVaults.length;
        if (numOfVaults == 0) revert Errors.EmptyArray();
        if (numOfVaults != _lpTokens.length) revert Errors.InconsistentArrayLength();
        if (numOfVaults != _amounts.length) revert Errors.InconsistentArrayLength();
        for (uint256 i; i < numOfVaults; ++i) {
            ISavETHVault vault = ISavETHVault(_savETHVaults[i]);

            uint256 numOfTokens = _lpTokens[i].length;
            for (uint256 j; j < numOfTokens; ++j) {
                if (vault.isDETHReadyForWithdrawal(address(_lpTokens[i][j]))) revert Errors.ETHStakedOrDerivativesMinted();

                // Disassociate stake count
                bytes memory blsPubKey = vault.KnotAssociatedWithLPToken(address(_lpTokens[i][j]));
                _onBringBackETHToGiantPool(blsPubKey);
                isBLSPubKeyFundedByGiantPool[blsPubKey] = false;

                // Increase the amount of ETH that's idle
                idleETH += _amounts[i][j];
            }

            // Burn LP tokens belonging to a specific vault in order to get the vault to send ETH
            vault.burnLPTokens(_lpTokens[i], _amounts[i]);
        }
    }

    function beforeTokenTransfer(address _from, address _to, uint256) external {
        // Do nothing
    }

    // For bringing back ETH to the giant pool from a savETH vault
    receive() external payable {}

    /// @dev Check the msg.sender has enough giant LP to burn and that the pool has enough savETH vault LP
    function _assertUserHasEnoughGiantLPToClaimVaultLP(IERC20 _token, uint256 _amount) internal view {
        if (_amount < MIN_STAKING_AMOUNT) revert Errors.InvalidAmount();
        if (_token.balanceOf(address(this)) < _amount) revert Errors.InvalidBalance();
    }

    function _assertContractNotPaused() internal view override {
        if (paused()) revert ContractPaused();
    }

    function _init(
        address _lpDeployer,
        address _feesAndMevGiantPool,
        address _upgradeManager
    ) internal virtual {
        lpTokenETH = GiantLP(GiantLPDeployer(_lpDeployer).deployToken(address(this), address(this), "GiantETHLP", "gETH"));
        feesAndMevGiantPool = _feesAndMevGiantPool;
        batchSize = 24 ether;
        _transferOwnership(_upgradeManager);
    }
}
