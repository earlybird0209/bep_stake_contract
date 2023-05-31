require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "bscTestNet",
  networks: {
    bscTestNet: {
      url: "https://data-seed-prebsc-1-s3.binance.org:8545",
      blockGasLimit: 30000000, // whatever you want here,
      accounts: [process.env.PRIVATE_KEY, process.env.PRIVATE_KEY_WALLET1],
    },
    hardhat: {
      chainId: 31337, // We set 1337 to make interacting with MetaMask simpler
      accounts: [{
        privateKey: process.env.PRIVATE_KEY,
        balance: '1000000000000000000000000000'
      }, {
        privateKey: process.env.PRIVATE_KEY_WALLET1,
        balance: '1000000000000000000000000000'
      }],
      gas: "auto",
      gasPrice: "auto",
      
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.5.16",
        settings: {},
      },
    ],
  },
  //solidity: "0.8.17",
  settings: {
    optimizer: {
      //   enabled: withOptimizations,
      runs: 200,
    },
  },
  etherscan: {
    // apiKey: "a93066703ed9ac3afb84b34e7c1cd3a2",// Ropsten Ether API
    //apiKey: "U6Y6XR19NT3314IKJJUKJZ8689JEHM13MZ",// BSC API
    // apiKey: "47EUCZERJIJ827FJUE684972AZ7AI8899N",// Etherscan API
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice",
  },
 
};
