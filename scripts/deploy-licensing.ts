import { ethers } from "hardhat";
import { JsonRpcProvider, Wallet } from "ethers";
import dotenv from "dotenv";

dotenv.config();

class LicensingDeployer {
    private provider: any;
    private deployer!: any;
    private licensee!: Wallet;
    private licensingContract: any;

    constructor() { }

    async initialize() {
        this.provider = new JsonRpcProvider(process.env.HEDERA_RPC_URL);
        [this.deployer] = await ethers.getSigners()
        this.licensee = new Wallet(process.env.LICENSEE_PRIVATE_KEY!, this.provider);
        console.log("Deployer:", this.deployer.address);
        console.log("Licensee:", this.licensee.address);
    }

    async deployContract() {
        const Licensing = await ethers.getContractFactory("Licensing");
        this.licensingContract = await Licensing.deploy();
        await this.licensingContract.waitForDeployment();
        const contractAddress = await this.licensingContract.getAddress();
        console.log(`Licensing Contract deployed at: ${contractAddress}`);
    }

    async issueLicenseTest(filmId: number, licenseFee: any) {
        const balance = await this.provider.getBalance(this.deployer.address);
        console.log("💰 Deployer Balance:", ethers.formatUnits(balance, 8));
        if (balance === 0n) {
            throw new Error("❌ Deployer has no funds. Please use the Hedera faucet.");
        }
        console.log(`Issuing license for Film ID: ${filmId} with fee ${licenseFee} HBAR`);

        const issueTx = await this.licensingContract.connect(this.deployer).issueLicense(filmId, this.licensee.address, { value: licenseFee });
        await issueTx.wait();

        console.log(`License issued to ${this.licensee.address} for Film ID: ${filmId}`);
    }

    async revokeLicenseTest(filmId: number) {
        console.log(`Revoking license for Film ID: ${filmId}`);

        const revokeTx = await this.licensingContract.connect(this.deployer).revokeLicense(filmId);
        await revokeTx.wait();

        console.log(`License revoked for Film ID: ${filmId}`);
    }

    async listLicenseDetails(filmId: number) {
        console.log(`Fetching license details for Film ID: ${filmId}`);

        const licenseDetails = await this.licensingContract.filmLicenses(filmId);
        console.log(`Licensee: ${licenseDetails.licensee}`);
        console.log(`Expiry: ${licenseDetails.expiry}`);
        console.log(`Revenue: ${ethers.formatUnits(licenseDetails.revenue, 8)} HBAR`);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();

            const filmId = 1;
            const licenseFee = ethers.parseUnits("1", 18);

            // Test issuing a license
            await this.issueLicenseTest(filmId, licenseFee);

            // Check license details
            await this.listLicenseDetails(filmId);

            // Test revoking the license
            await this.revokeLicenseTest(filmId);

            console.log("All Licensing tests completed successfully!");
        } catch (error) {
            console.error("Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new LicensingDeployer();
deployer.run();
