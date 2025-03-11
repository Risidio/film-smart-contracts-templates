import { ethers } from "hardhat";
import { JsonRpcProvider } from "ethers";
import dotenv from "dotenv";

dotenv.config();

class InvestmentDeployer {
    private provider: any;
    private deployer: any;
    private investor1: any;
    private investor2: any;
    private investmentContract: any;

    constructor() {}

    async initialize() {
        [this.deployer, this.investor1, this.investor2] = await ethers.getSigners();
        console.log("Deployer:", this.deployer.address);
        console.log("Investor1:", this.investor1.address);
        console.log("Investor2:", this.investor2.address);
    }

    async deployContract() {
        const Investment = await ethers.getContractFactory("Investment");
        this.investmentContract = await Investment.deploy();
        await this.investmentContract.waitForDeployment();
        const contractAddress = await this.investmentContract.getAddress();
        console.log(`Investment Contract deployed at: ${contractAddress}`);
    }

    async investInFilmTest(filmId: number, investor: any, amount: any) {
        console.log(`Investor (${investor.address}) investing ${ethers.formatEther(amount)} ETH in Film ID: ${filmId}`);

        const investTx = await this.investmentContract.connect(investor).invest(filmId, { value: amount });
        await investTx.wait();

        console.log(`Investor (${investor.address}) successfully invested ${ethers.formatEther(amount)} ETH`);
    }

    async withdrawInvestmentTest(filmId: number, investor: any, amount: any) {
        console.log(`Investor (${investor.address}) attempting to withdraw ${ethers.formatEther(amount)} ETH from Film ID: ${filmId}`);

        const withdrawTx = await this.investmentContract.connect(investor).withdrawInvestment(filmId, amount);
        await withdrawTx.wait();

        console.log(`Investor (${investor.address}) successfully withdrew ${ethers.formatEther(amount)} ETH`);
    }

    async checkTotalInvestment(filmId: number) {
        const totalInvestment = await this.investmentContract.getTotalInvestment(filmId);
        console.log(`Total Investment in Film ID ${filmId}: ${ethers.formatEther(totalInvestment)} ETH`);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();

            const filmId = 1;
            const investAmount1 = ethers.parseEther("1"); // 1 ETH
            const investAmount2 = ethers.parseEther("2"); // 2 ETH
            const withdrawAmount = ethers.parseEther("0.5"); // 0.5 ETH

            // Test investments
            await this.investInFilmTest(filmId, this.investor1, investAmount1);
            await this.investInFilmTest(filmId, this.investor2, investAmount2);

            // Check total investment
            await this.checkTotalInvestment(filmId);

            // Test withdrawal
            await this.withdrawInvestmentTest(filmId, this.investor1, withdrawAmount);

            // Final total investment check
            await this.checkTotalInvestment(filmId);

            console.log("All Investment tests completed successfully!");
        } catch (error) {
            console.error("Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new InvestmentDeployer();
deployer.run();
