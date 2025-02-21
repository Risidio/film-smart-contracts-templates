const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contract with account:", deployer.address);

  const WebNFT = await hre.ethers.getContractFactory("WebNFT");
  const webNFTInstance = await WebNFT.deploy(deployer.address);

  await webNFTInstance.waitForDeployment();
  console.log("WebNFT deployed to:", await webNFTInstance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
