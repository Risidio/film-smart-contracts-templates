import { ethers } from "hardhat";
import { JsonRpcProvider } from "ethers";
import dotenv from "dotenv";

dotenv.config();

class RevenueSplitDeployer {
    private provider: any;
    private deployer: any;
    private investor1: any;
    private investor2: any;
    private revenueContract: any;

    constructor() {}

    async initialize() {
        [this.deployer, this.investor1, this.investor2] = await ethers.getSigners();
        console.log("Deployer:", this.deployer.address);
        console.log("Investor1:", this.investor1.address);
        console.log("Investor2:", this.investor2.address);
    }

    async deployContract() {
        const RevenueSplit = await ethers.getContractFactory("RevenueSplit");
        this.revenueContract = await RevenueSplit.deploy();
        await this.revenueContract.waitForDeployment();
        const contractAddress = await this.revenueContract.getAddress();
        console.log(`RevenueSplit Contract deployed at: ${contractAddress}`);
    }

    async distributeRevenueTest(filmId: number, amount: any) {
        console.log(`Depositing ${ethers.formatEther(amount)} ETH revenue for Film ID: ${filmId}`);

        const distributeTx = await this.revenueContract.connect(this.deployer).distributeRevenue(filmId, { value: amount });
        await distributeTx.wait();

        console.log(`Revenue of ${ethers.formatEther(amount)} ETH distributed for Film ID: ${filmId}`);
    }

    async claimRevenueTest(filmId: number, investor: any) {
        console.log(`Investor (${investor.address}) claiming revenue for Film ID: ${filmId}`);

        const claimTx = await this.revenueContract.connect(investor).claimRevenue(filmId);
        await claimTx.wait();

        console.log(`Investor (${investor.address}) successfully claimed revenue for Film ID: ${filmId}`);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();

            const filmId = 1;
            const revenueAmount = ethers.parseEther("5"); // 5 ETH

            // Test revenue distribution
            await this.distributeRevenueTest(filmId, revenueAmount);

            // Test revenue claiming by investors
            await this.claimRevenueTest(filmId, this.investor1);
            await this.claimRevenueTest(filmId, this.investor2);

            console.log("All RevenueSplit tests completed successfully!");
        } catch (error) {
            console.error("Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new RevenueSplitDeployer();
deployer.run();