import { ethers } from "hardhat";
import { BaseFilmContract, FilmInvestmentContract } from "../typechain-types";
import { uploadMetadataToIPFS, uploadToIPFS } from "./upload";

async function main() {
    const [deployer] = await ethers.getSigners();    
    const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

    const FilmInvestmentContract = await ethers.getContractFactory("FilmInvestmentContract");
    const contract = FilmInvestmentContract.attach(CONTRACT_ADDRESS) as FilmInvestmentContract;

    console.log(`Interacting with contract at: ${CONTRACT_ADDRESS}`);

    const title = await contract.filmMetadataURI();
    console.log(`Film Metadata URI: ${title}`);

    const investmentAmount = ethers.parseUnits("100", 18);
    const investment = await contract.connect(deployer).invest(investmentAmount);

    console.log("⏳ Waiting for transaction confirmation...");
    await investment.wait();

    console.log(`✅ Investment of ${ethers.formatUnits(investmentAmount, 18)} USDT successful!`);
    console.log(`Investment: ${investment}`);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
