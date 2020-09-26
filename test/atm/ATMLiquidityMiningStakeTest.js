// JS Libraries
const helper = require("../utils/time-block-helper");
const withData = require("leche").withData;
const { t } = require("../utils/consts");
const { assert } = require("chai");
const { liquidityMining } = require("../utils/events");

// Mock contracts
const Mock = artifacts.require("./mock/util/Mock.sol");

// Smart contracts
const TDAI = artifacts.require("./base/TDAI.sol");
const TLRToken = artifacts.require("./atm/TLRToken.sol");
const ATMGovernance = artifacts.require("./atm/ATMGovernance.sol");
const ATMLiquidityMiningMock = artifacts.require("./atm/ATMLiquidityMiningMock.sol");

contract("ATMLiquidityMiningStakeTest", function(accounts) {
    const owner = accounts[0]; 
    const user = accounts[2];
    const INITIAL_REWARD = 1;
    let instance;
    let governance;
    let tlr;

    
    beforeEach("Setup for each test", async () => {
        const settingsInstance = await Mock.new();
        governance = await ATMGovernance.new();
        await governance.initialize(settingsInstance.address, owner, INITIAL_REWARD);
        tlr = await TLRToken.new();
        tToken = await TDAI.new();
        instance = await ATMLiquidityMiningMock.new();
        await instance.initialize(settingsInstance.address, governance.address, tlr.address, { from: owner });
    });

    withData({
        _1_basic: [ 10, 0, false, undefined ],
        _2_not_enough_tTokens: [ 10, 1, true, "INSUFFICIENT_TTOKENS_TO_STAKE" ],
    }, function(amount, offset, mustFail, expectedErrorMessage) {
        it(t("user", "stake#1-one-reward-one-stake", "Should be able or not to stake tTokens.", mustFail), async function() {
            // Setup
            await tToken.mint(user, amount, { from: owner });
            const userBalanceBefore = await tToken.balanceOf(user);
            const liquidityBalanceBefore = await tToken.balanceOf(instance.address);
            await tToken.approve(instance.address, amount, { from: user });

            try {
                // Invocation 
                const result = await instance.stake(tToken.address, amount + offset , { from: user });
                // Assertions
                assert(!mustFail, 'It should have failed because data is invalid.');
                // Validating result
                const userBalanceAfter = await tToken.balanceOf(user);
                assert(parseInt(userBalanceAfter) < parseInt(userBalanceBefore), 'user tTokens not sent on stake.');
                const liquidityBalanceAfter = await tToken.balanceOf(instance.address);
                assert(parseInt(liquidityBalanceAfter) > parseInt(liquidityBalanceBefore), 'tTokens not received on stake.');
                assert(parseInt(liquidityBalanceAfter) == parseInt(userBalanceBefore), 'tTokens received are less than sent amount.');
                // Validating events were emitted
                liquidityMining
                    .stake(result)
                    .emitted(user, tToken.address, amount, result.receipt.blockNumber, amount, 0);
            } catch (error) {
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, expectedErrorMessage);
            }
        });
    });
    withData({
        _1_one_reward_multi_stake: [ [10, 20, 30, 5, 3], false, undefined ],
    }, function(amounts, mustFail, expectedErrorMessage) {
        it(t("user", "stake#2-one-reward-multiple-stakes", "Should be able or not to stake tTokens.", mustFail), async function() {
            try {
                // Setup
                let totalAmount = 0;
                let userBalanceBefore = 0;
                let liquidityBalanceAfter = 0;
                for (let i = 0; i < amounts.length; i++) {
                    totalAmount += parseInt(amounts[i]);
                    await tToken.mint(user, amounts[i], { from: owner });
                    await tToken.approve(instance.address, totalAmount, { from: user });
                    userBalanceBefore += parseInt(await tToken.balanceOf(user));
                    // Invocation 
                    const result = await instance.stake(tToken.address, amounts[i] , { from: user });
                    // Assertions
                    assert(!mustFail, 'It should have failed because data is invalid.');
                    // Validating result
                    liquidityBalanceAfter = parseInt(await tToken.balanceOf(instance.address)) ;
                    // Validating events were emitted
                    liquidityMining
                        .stake(result)
                        .emitted(user, tToken.address, amounts[i], result.receipt.blockNumber, totalAmount); // accruedTLR validated on calculateAccruedTLR test.
                }
            } catch (error) {
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, expectedErrorMessage);
            }
        });
    });
    
    withData({
        _1_multi_reward_multi_stake: [ [10, 100], [20, 200, 2000], false, undefined ],
    }, function(amounts, rewards, mustFail, expectedErrorMessage) {
        it(t("user", "stake#3-multiple-rewards-multiple-stakes", "Should be able or not to stake tTokens.", mustFail), async function() {
            // Setup
            await tToken.mint(user, amounts[0], { from: owner });
            await tToken.approve(instance.address, amounts[0], { from: user });
            await instance.stake(tToken.address, amounts[0] , { from: user });
            const totalAmount = amounts[0] + amounts[1];        
            for (let r = 0; r < rewards.length; r++){
                await helper.advanceBlocks(rewards[r]);
                await governance.addTLRReward(rewards[r], { from: owner});
            }
            await tToken.mint(user, amounts[1], { from: owner });
            await tToken.approve(instance.address, totalAmount, { from: user });
            
            try {
                // Invocation 
                const result = await instance.stake(tToken.address, amounts[1] , { from: user });
                // Assertions
                assert(!mustFail, 'It should have failed because data is invalid.');
                // Validating result
                liquidityBalanceAfter = parseInt(await tToken.balanceOf(instance.address)) ;
                assert( liquidityBalanceAfter == totalAmount);
                // Validating events were emitted
                liquidityMining
                    .stake(result)
                    .emitted(user, tToken.address, amounts[1], result.receipt.blockNumber, totalAmount); // accruedTLR validated on calculateAccruedTLR test.
            } catch (error) {
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, expectedErrorMessage);
            }
        });
    });
});
