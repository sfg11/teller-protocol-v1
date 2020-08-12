module.exports = {
    network: 'ropsten',
    chainlink: require('./chainlink'),
    compound: require('./compound'),
    dao: require('./dao'),
    tokens: require('./tokens'),
    teller: require('./teller'),
    assetSettings: require('./assetSettings'),
    platformSettings: require('./platformSettings'),
    maxGasLimit: 7000000,
    toTxUrl: ({ tx }) => {
        return `https://ropsten.etherscan.io/tx/${tx}`;
    },
};
