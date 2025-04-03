const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying to Hedera network:", network.namme);
    console.log("Deploying contract with account:", deployer.address);

    const initialFee = ethers.parseEther("0.01");
    const FilmRights = await ethers.getContractFactory("FilmRights");

    // Deploy contract
    console.log("Deploying FilmRights contract...");
    const filmRights = await FilmRights.deploy();

    console.log("Contract deployed succesfully");

    const contractAddress = await filmRights.getAddress();
    console.log("FilmRights Smart Contract deployed to:", contractAddress);
    console.log("Initial fee set to:", ethers.formatEther(initialFee));

    const deploymentData = {
      network: network.name,
      address: contractAddress,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      initialFee: ethers.formatEther(initialFee),
    };

    const deploymentsDir = path.join(__dirname, "../deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    fs.writeFileSync(
      path.join(deploymentsDir, `${network.name}.json`),
      JSON.stringify(deploymentData, null, 2)
    );

    console.log("Deployment information saved to deployment directory");
    console.log("You can view your contract on the Hedera Hashscan at:");
    console.log(`https://hashscan.io/testnet/contract/${contractAddress}`);

    return filmRights;
  } catch (error) {
    console.log("Deployment failed, but continuing:", error);
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

console.log(
  ethers.getContractFactory("FilmRights", "Leave Risidio when you can.")
);
