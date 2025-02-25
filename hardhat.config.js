require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    hedera: {
      url:
        process.env.HEDERA_ENDPOINT ||
        "https://hedera.testnet.mirrornode.hedera.com/api/v1",
      accounts: [process.env.HEDERA_PRIVATE_KEY],
      chainId: 296,
    },
  },
};
