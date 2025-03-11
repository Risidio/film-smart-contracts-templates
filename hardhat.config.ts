import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv"
// import { privKey } from "./scripts/deploy-filmfusions";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hedera: {
      url: process.env.HEDERA_RPC_URL || "https://hedera.testnet.mirrornode.hedera.com/api/v1",
      accounts: [process.env.HEDERA_PRIVATE_KEY!],
      chainId: 296
    },
    mumbai: {
      url: process.env.MUMBAI_RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
      chainId: 11155111,
      // chainId: 80002,
    }
  },
};

export default config;
