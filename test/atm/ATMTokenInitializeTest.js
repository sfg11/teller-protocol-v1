// JS Libraries
const withData = require('leche').withData;
const { t } = require('../utils/consts');

// Smart contracts
const ATMToken = artifacts.require('./ATMToken.sol');

contract('ATMTokenInitializeTest', function (accounts) {

    withData({
        _1_initialize_basic: ['ATMToken', 'ATMT', 18, 10000, 50, undefined, false],
        _2_initialize_zero_cap: ['ATMToken', 'ATMT', 18, 0, 50, "CAP_CANNOT_BE_ZERO", true]
    }, function (
        name,
        symbol,
        decimals,
        cap,
        maxVestings,
        expectedErrorMessage,
        mustFail
    ) {
        it(t('user', 'initialize', 'Should or should not be able to create a new instance.', mustFail), async function() {
            // Setup
            const instance = await ATMToken.new();
            try {
                const result = await instance.initialize(name, symbol, decimals, cap, maxVestings);

                // Assertions
                assert(!mustFail, 'It should have failed because data is invalid.');
                assert(result);
            } catch (error) {
                // Assertions
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, expectedErrorMessage);
            }   
        });
    });
});