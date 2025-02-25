const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const contractAddress = "0x111c8318c66d85f49d3e6db081e68313fb5af35a";
  const ipfsHash = "QmNNcmqxJKAqd41DFXLL9mrgHtG6XJfEgGkepa4adYhxY7";

  const NFTContract = await ethers.getContractFactory("WebNFT");
  const nftContract = await NFTContract.attach(contractAddress);

  console.log("Minting NFT...");

  const tx = await nftContract.safeMint(
    process.env.HEDERA_WALLET_ADDRESS,
    `ipfs://${ipfsHash}`
  );

  await tx.wait();

  console.log(`NFT minted successfully! Transaction hash: ${tx.hash}`);
  console.log(`Token minted to: ${process.env.HEDERA_WALLET_ADDRESS}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
