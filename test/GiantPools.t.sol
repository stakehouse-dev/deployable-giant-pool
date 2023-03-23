// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";

contract GiantPoolTests is Test {

    function setUp() public {}

    function testGiantPoolDepositQueue() public {
        // Set up users and ETH
        address nodeRunner = accountOne; vm.deal(nodeRunner, 100 ether);
        address feesAndMevUserOne = accountTwo; vm.deal(feesAndMevUserOne, 100 ether);
        address savETHUser = accountThree; vm.deal(savETHUser, 100 ether);
        address savETHUserTwo = accountFive; vm.deal(savETHUserTwo, 100 ether);
        address savETHUserThree = accountSix; vm.deal(savETHUserThree, 100 ether);

        // Register BLS key
        registerSingleBLSPubKey(nodeRunner, blsPubKeyOne, accountFour);
        registerSingleBLSPubKey(nodeRunner, blsPubKeyTwo, accountFour);

        // Fund the giant pool in waves
        assertEq(giantSavETHPool.totalETHFromLPs(), 0);
        vm.startPrank(savETHUser);
        giantSavETHPool.depositETH{value: 10 ether}(10 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.totalETHFromLPs(), 10 ether);
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUser), 1);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 0), 0);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 0), 10 ether);
        assertEq(giantSavETHPool.depositBatchCount(), 0);

        vm.startPrank(savETHUserTwo);
        giantSavETHPool.depositETH{value: 14 ether}(14 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUserTwo), 1);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUserTwo, 0), 14 ether);
        assertEq(giantSavETHPool.depositBatchCount(), 1);

        vm.startPrank(savETHUserThree);
        giantSavETHPool.depositETH{value: 25 ether}(25 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUserThree), 2);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUserThree, 1), 24 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUserThree, 2), 1 ether);
        assertEq(giantSavETHPool.depositBatchCount(), 2);

        vm.startPrank(savETHUser);
        giantSavETHPool.depositETH{value: 47.17 ether}(47.17 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.depositBatchCount(), 4);
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUser), 4);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 0), 0);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 1), 2);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 2), 3);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 3), 4);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 0), 10 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 2), 23 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 3), 24 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 4), 0.17 ether);

        vm.warp(block.timestamp + 50 minutes);

        vm.startPrank(savETHUser);
        giantSavETHPool.withdrawETH(12.49 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 0), 10 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 2), 23 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 3), 24 ether - 12.32 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 4), 0 ether);
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUser), 3);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 0), 0);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 1), 2);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 2), 3);
        assertEq(giantSavETHPool.depositBatchCount(), 4); // Since recycled batches take care of gaps

        vm.startPrank(savETHUser);
        giantSavETHPool.lpTokenETH().transfer(savETHUserTwo, 11.68 ether);
        vm.stopPrank();
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 0), 10 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 2), 23 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 3), 0 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUser, 4), 0 ether);
        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUser), 2);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 0), 0);
        assertEq(giantSavETHPool.getAssociatedDepositBatchIDAtIndex(savETHUser, 1), 2);
        assertEq(giantSavETHPool.depositBatchCount(), 4);

        assertEq(giantSavETHPool.getSetOfAssociatedDepositBatchesSize(savETHUserTwo), 2);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUserTwo, 0), 14 ether);
        assertEq(giantSavETHPool.totalETHFundedPerBatch(savETHUserTwo, 3), 11.68 ether);
    }
}