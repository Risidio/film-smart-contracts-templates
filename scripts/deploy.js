const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying to Hedera network:", network.name);
    console.log("Deploying contract with account:", deployer.address);
    const FilmLicensing = await ethers.getContractFactory("FilmLicensing");

    // Deploy contract
    console.log("Deploying FilmLicensing contract...");
    const filmLicensing = await FilmLicensing.deploy();

    console.log("Waiting for deployment transaction confirmation...");
    await filmLicensing.waitForDeployment();

    const contractAddress = await filmLicensing.getAddress();
    console.log("FilmLicensing Smart Contract deployed to:", contractAddress);


    // Save deployment details
    const deploymentData = {
      network: network.name,
      address: contractAddress,
      deployer: deployer.address,
    };

    const deploymentsDir = path.join(__dirname, "../deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir);
    }

    fs.writeFileSync(
      path.join(deploymentsDir, `${network.name}.json`),
      JSON.stringify(deploymentData, null, 2)
    );

    console.log("Deployment information saved to deployments directory");
    console.log("You can view your contract on the Hedera Hashscan at:");
    console.log(`https://hashscan.io/testnet/contract/${contractAddress}`);
    return filmLicensing;
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

async function runMain() {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.error("Unhandled error:", error);
    process.exit(1);
  }
}

runMain();
