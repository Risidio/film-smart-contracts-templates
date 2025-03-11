import { ethers } from "hardhat";
import { JsonRpcProvider } from "ethers";
import dotenv from "dotenv";

dotenv.config();

class StreamingPayoutsDeployer {
    private deployer: any;
    private rightsHolder: any;
    private filmContract: any;

    constructor() {}

    async initialize() {
        [this.deployer, this.rightsHolder] = await ethers.getSigners();
        console.log("Deployer:", this.deployer.address);
        console.log("Rights Holder:", this.rightsHolder.address);
    }

    async deployContract() {
        const StreamingPayouts = await ethers.getContractFactory("StreamingPayouts");
        this.filmContract = await StreamingPayouts.deploy();
        await this.filmContract.waitForDeployment();
        const contractAddress = await this.filmContract.getAddress();
        console.log(`StreamingPayouts Contract deployed at: ${contractAddress}`);
    }

    async collectStreamingRevenue(filmId: number, amount: any) {
        console.log(`Collecting streaming revenue for Film ID: ${filmId}, Amount: ${amount} ETH`);
        const tx = await this.filmContract.connect(this.deployer).collectStreamingRevenue(filmId, { value: ethers.parseEther(amount.toString()) });
        await tx.wait();
        console.log(`Streaming revenue of ${amount} ETH collected for Film ID: ${filmId}`);
    }

    async distributeStreamingPayout(filmId: number) {
        console.log(`Distributing streaming revenue for Film ID: ${filmId}`);
        const tx = await this.filmContract.connect(this.deployer).distributeStreamingPayout(filmId);
        await tx.wait();
        console.log(`Streaming payout successfully distributed for Film ID: ${filmId}`);
    }

    async getStreamingRevenue(filmId: number) {
        const revenue = await this.filmContract.filmStreamingRevenue(filmId);
        console.log(`Total Streaming Revenue for Film ID ${filmId}: ${ethers.formatEther(revenue)} ETH`);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();

            const filmId = 1; // Example Film ID
            const revenueAmount = 1; // 1 ETH

            await this.collectStreamingRevenue(filmId, revenueAmount);
            await this.getStreamingRevenue(filmId);

            await this.distributeStreamingPayout(filmId);

            await this.getStreamingRevenue(filmId);

            console.log("All StreamingPayouts tests completed successfully!");
        } catch (error) {
            console.error("Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new StreamingPayoutsDeployer();
deployer.run();
