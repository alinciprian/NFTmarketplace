import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";


const config: HardhatUserConfig = {
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

export default config;
