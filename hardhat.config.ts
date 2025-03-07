import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv"
import { privKey } from "./scripts/deploySecondary";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hedera: {
      url: process.env.HEDERA_RPC_URL || "https://hedera.testnet.mirrornode.hedera.com/api/v1",
      accounts: [process.env.HEDERA_PRIVATE_KEY!],
      chainId: 296
    },
  },
};

export default config;
