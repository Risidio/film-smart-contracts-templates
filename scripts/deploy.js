const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying to Hedera network:", network.name);
    console.log("Deploying contract with account:", deployer.address);

    const initialFee = ethers.parseEther("0.01"); // Example: 0.01 HBAR equivalent
    const FilmRights = await ethers.getContractFactory("FilmRights");

    // Deploy contract
    console.log("Deploying FilmRights contract...");
    const filmRights = await FilmRights.deploy(initialFee);

    console.log("Waiting for deployment transaction confirmation...");
    await filmRights.waitForDeployment();

    const contractAddress = await filmRights.getAddress();
    console.log("FilmRights Smart Contract deployed to:", contractAddress);
    console.log("Initial fee set to:", ethers.formatEther(initialFee));

    // Save deployment details
    const deploymentData = {
      network: network.name,
      address: contractAddress,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      initialFee: ethers.formatEther(initialFee),
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

    return filmRights;
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
