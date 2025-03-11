import { ethers } from "hardhat";
import { JsonRpcProvider, Wallet } from "ethers";
import dotenv from "dotenv";

dotenv.config();

class FilmNFTDeployer {
    private provider!: JsonRpcProvider;
    private deployer!: any;
    private producer!: Wallet;
    private newOwner!: Wallet;
    private filmContract: any;

    constructor() {}

    async initialize() {
        if (!process.env.HEDERA_RPC_URL || !process.env.DEPLOYER_PRIVATE_KEY) {
            throw new Error("❌ Missing environment variables in .env file.");
        }

        this.provider = new JsonRpcProvider(process.env.HEDERA_RPC_URL);

        // Validate Private Keys
        if (!process.env.DEPLOYER_PRIVATE_KEY) {
            throw new Error("❌ Invalid DEPLOYER_PRIVATE_KEY format. It must start with '0x'");
        }

        [ this.deployer ] = await ethers.getSigners()        
        this.producer = new Wallet(process.env.LICENSEE_PRIVATE_KEY!, this.provider);
        this.newOwner = new Wallet(process.env.LICENSEE_PRIVATE_KEY!, this.provider);

        console.log("✅ Deployer:", this.deployer.address);
        console.log("✅ Producer:", this.producer.address);
        console.log("✅ New Owner:", this.newOwner.address);

        // Check if account has funds
        const balance = await this.provider.getBalance(this.deployer.address);
        console.log(`💰 Deployer Balance: ${ethers.formatUnits(balance, 8)} HBAR`);
        if (balance === 0n) {
            throw new Error("❌ Deployer has no funds. Please use the Hedera faucet.");
        }
    }

    async deployContract() {
        console.log("🚀 Deploying FilmNFT contract...");
        const FilmNFT = await ethers.getContractFactory("FilmNFT", this.deployer);
        this.filmContract = await FilmNFT.deploy();
        await this.filmContract.waitForDeployment();
        console.log(`✅ FilmNFT Contract deployed at: ${await this.filmContract.getAddress()}`);
    }

    async mintFilmNFT(title: string, metadataURI: string): Promise<number> {
        console.log(`🎬 Creating film NFT with title: ${title}`);

        const mintTx = await this.filmContract
            .connect(this.deployer)
            .createFilm(title, metadataURI, { gasLimit: 3000000 });

        const receipt = await mintTx.wait();
        console.log("✅ Film NFT Minted!");

        // Find event in logs
        const filmCreatedEvent = receipt.logs.find((log: any) => {
            try {
                return this.filmContract.interface.parseLog(log).name === "FilmCreated";
            } catch (e) {
                return false;
            }
        });

        if (!filmCreatedEvent) {
            throw new Error("❌ FilmCreated event not found!");
        }

        const filmId = filmCreatedEvent.args[0];
        console.log(`🎬 Film ID: ${filmId}`);
        return filmId;
    }

    async transferFilmOwnershipTest(filmId: number, from: Wallet, to: Wallet) {
        console.log(`🔄 Transferring Film ID ${filmId} from ${from.address} to ${to.address}`);
        const transferTx = await this.filmContract.connect(from).transferFilmOwnership(filmId, to.address);
        await transferTx.wait();
        console.log("✅ Ownership Transferred!");
    }

    async getFilmDetailsTest(filmId: number) {
        const [title, producer] = await this.filmContract.getFilmDetails(filmId);
        console.log(`🎥 Film ID: ${filmId}`);
        console.log(`📌 Title: ${title}`);
        console.log(`🎬 Producer: ${producer}`);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();

            const metadataURI = "ipfs://example-metadata-uri";
            const filmId = await this.mintFilmNFT("Sci-Fi Film", metadataURI);

            await this.getFilmDetailsTest(filmId);

            await this.transferFilmOwnershipTest(filmId, this.deployer, this.newOwner);

            await this.getFilmDetailsTest(filmId);

            console.log("✅ All tests completed successfully!");
        } catch (error) {
            console.error("❌ Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new FilmNFTDeployer();
deployer.run();
