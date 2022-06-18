const path = require("path");
const goerli_private="f7cb6dbb8148c2a5d7ad2e514416258bdef3e3337093e98068cb24bb1ce6faee"
const HDWalletProvider = require('@truffle/hdwallet-provider');
module.exports = {

  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : { excludeContracts: ['Migrations'] }
  },
  plugins: ["solidity-coverage"],
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  contracts_build_directory: path.join(__dirname, "client/src/contracts"),
  networks: {
  development: {
    //provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`),
    host: "127.0.0.1",     // Localhost (default: none)
    port: 8545,            // Standard Ethereum port (default: none)
    network_id: "*",       // Any network (default: none)
  },


  ccm_test: {
    provider: () => new HDWalletProvider(goerli_private, `http://123.58.217.221:9933`), //  http://123.58.217.221:9933
    network_id: 87,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    confirmations: 1,    // # of confs to wait between deployments. (default: 0)  UV_THREADPOOL_SIZE=20 truffle migrate --reset --network ccm_test
    timeoutBlocks: 200000,  // # of blocks before a deployment times out  (minimum/default: 50)
    skipDryRun: true,     // Skip dry run before migrations? (default: false for public nets )
      networkCheckTimeout:1000000000,
    },
  goerli: {
    provider: () => new HDWalletProvider(goerli_private, `https://goerli.infura.io/v3/a79d66ef23ce4b4a9d44bf1e13768c73`),
    network_id: 5,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    confirmations: 1,    // # of confs to wait between deployments. (default: 0)
    timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
  },
  compilers: {
    solc: {
      version: "0.8.9",    // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 200
       },
       //evmVersion: "byzantium"
      }
    }
  },
};
