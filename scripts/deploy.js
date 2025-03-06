// const hre = require("hardhat");

// async function main() {
//   const [deployer] = await hre.ethers.getSigners();
//   console.log("Deploying contract with account:", deployer.address);

//   const WebNFT = await hre.ethers.getContractFactory("WebNFT");
//   const webNFTInstance = await WebNFT.deploy(deployer.address);

//   await webNFTInstance.waitForDeployment();
//   console.log("WebNFT deployed to:", await webNFTInstance.getAddress());
// }

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });

const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {
  // Verify Hedera network configuration
  if (hre.network.name !== "hedera") {
    console.warn(
      "Deploying to non-Hedera network. Ensure correct network configuration."
    );
  }

  // Get the deploying account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Check deployer balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "HBAR");

  // Deploy the FilmLicenseNFT contract
  const FilmLicenseNFT = await ethers.getContractFactory("FilmLicenseNFT");
  const filmLicenseNFT = await FilmLicenseNFT.deploy();

  // Wait for the contract to be deployed
  await filmLicenseNFT.waitForDeployment();

  console.log("FilmLicenseNFT deployed to:", await filmLicenseNFT.getAddress());

  // // Example of issuing a sample license (optional)
  try {
    const filmmaker = "0x052A008C2675e6266c352A17ca5a4aB7adCA9F76"; // Replace with actual address
    const tokenId = 1;
    const royaltyPercentage = 10; // 10% royalty
    const licenseFee = ethers.parseEther("0.1"); // 0.1 HBAR license fee
    const isExclusive = true;
    const validityPeriod = 365 * 24 * 60 * 60; // 1 year in seconds

    const tx = await filmLicenseNFT.issueLicense(
      filmmaker,
      tokenId,
      royaltyPercentage,
      licenseFee,
      isExclusive,
      validityPeriod
    );

    await tx.wait();
    console.log("Sample license issued successfully");
  } catch (error) {
    console.error("Error issuing sample license:", error);
  }
}

// Hardhat recommended pattern for handling deployment errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
