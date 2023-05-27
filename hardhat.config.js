require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy")

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      live: false,
      chainId: 31337,
      // https://hardhat.org/hardhat-network/docs/guides/forking-other-networks
    },
    localhost: {
      live: false,
      chainId: 31337,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  // https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify

  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
      },
    },
  },
};
