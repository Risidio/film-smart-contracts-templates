const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contract with account:", deployer.address);

  const FilmRights = await hre.ethers.getContractFactory("FilmRights");
  const filmRights = await FilmRights.deploy();

  await filmRights.waitForDeployment();

  console.log("FilmRights Smart Contract deployed to:", filmRights.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
