import { ethers } from "hardhat";
import { testConnection, uploadMetadataToIPFS, uploadToIPFS } from "./upload";
import { ContractTransactionResponse, EventLog, Signer } from "ethers";

class FilmFusionDeployer {
    private deployer!: Signer;
    private investor1!: Signer;
    private investor2!: Signer;
    private licensee!: Signer;
    private buyer!: Signer;
    private filmContract: any;
    private usdtAddress: any;

    constructor(usdtAddress: any) {
        this.usdtAddress = usdtAddress;
        console.log("USDT Address:", this.usdtAddress);
    }

    async initialize() {
        [this.deployer, this.investor1, this.investor2, this.licensee, this.buyer] = await ethers.getSigners();
        console.log("Deployer:", await this.deployer.getAddress());
        console.log("Investor1:", await this.investor1.getAddress());
        console.log("Investor2:", await this.investor2.getAddress());
        console.log("Licensee:", await this.licensee.getAddress());
        console.log("Buyer:", await this.buyer.getAddress());

        await testConnection();
    }

    async deployContract() {
        const FilmFusion = await ethers.getContractFactory("FilmFusions");
        this.filmContract = await FilmFusion.deploy(this.usdtAddress);
        await this.filmContract.waitForDeployment();
        const contractAddress = await this.filmContract.getAddress();
        console.log(`FilmFusion Contract deployed at: ${contractAddress}`);
    }

    async uploadMetadata(filePath: string) {
        const fileCID = await uploadToIPFS(filePath);
        console.log("File CID:", fileCID);

        const metadata = {
            name: "Sci-Fi Film",
            description: "A groundbreaking Sci-Fi movie.",
            image: `ipfs://${fileCID}`,
            attributes: [
                { trait_type: "Genre", value: "Sci-Fi" },
                { trait_type: "Director", value: "John Doe" }
            ]
        };

        const metadataCID = await uploadMetadataToIPFS(metadata);
        console.log("Metadata CID:", metadataCID);
        return metadataCID;
    }

    async mintFilmNFT(metadataCID: string): Promise<number> {
        const mintTx: ContractTransactionResponse = await this.filmContract.createFilm(
            "Sci-Fi Film",
            `ipfs://${metadataCID}`
        );
        const receipt = await mintTx.wait();

        // Extract FilmCreated event from logs
        const filmCreatedEvent = receipt?.logs.find((log: any) => {
            try {
                const parsed = this.filmContract.interface.parseLog(log);
                return parsed.name === "FilmCreated";
            } catch (e) {
                return false;
            }
        }) as EventLog;

        if (!filmCreatedEvent) {
            throw new Error("FilmCreated event not found!");
        }

        const filmId = filmCreatedEvent.args[0];
        console.log(`Film NFT minted successfully! Film ID: ${filmId}`);
        return filmId;
    }

    async validateFilmExists(filmId: number) {
        const filmExists = await this.filmContract.filmExists(filmId);
        if (!filmExists) {
            throw new Error("Film does not exist");
        }
        console.log("Film exists!");
    }

    async investInFilm(filmId: number, investor: Signer, amount: number) {
        console.log(`Investor (${await investor.getAddress()}) investing ${amount} USDT in Film ID: ${filmId}`);
        const investTx = await this.filmContract.connect(investor).invest(filmId, amount);
        await investTx.wait();
        console.log(`Investor (${await investor.getAddress()}) successfully invested ${amount} USDT in Film ID: ${filmId}`);
    }

    async withdrawInvestmentTest(filmId: number, investor: Signer, amount: number) {
        console.log(`Investor (${await investor.getAddress()}) withdrawing ${amount} USDT from Film ID: ${filmId}`);
        const withdrawTx = await this.filmContract.connect(investor).withdrawInvestment(filmId, amount);
        await withdrawTx.wait();
        console.log(`Investor (${await investor.getAddress()}) successfully withdrew ${amount} USDT from Film ID: ${filmId}`);
    }

    async distributeRevenueTest(filmId: number, totalRevenue: number) {
        console.log(`Distributing ${totalRevenue} USDT revenue for Film ID: ${filmId}`);
        const distributeTx = await this.filmContract.connect(this.deployer).distributeRevenue(filmId, totalRevenue);
        await distributeTx.wait();
        console.log(`Revenue of ${totalRevenue} USDT distributed for Film ID: ${filmId}`);
    }

    async claimRevenueTest(filmId: number, investor: Signer) {
        console.log(`Investor (${await investor.getAddress()}) claiming revenue for Film ID: ${filmId}`);
        const claimTx = await this.filmContract.connect(investor).claimRevenue(filmId);
        await claimTx.wait();
        console.log(`Investor (${await investor.getAddress()}) successfully claimed revenue for Film ID: ${filmId}`);
    }

    async issueAndRevokeLicenseTest(filmId: number, licensee: Signer, price: number) {
        console.log(`Issuing license for Film ID: ${filmId} to ${await licensee.getAddress()} for ${price} USDT`);
        const issueTx = await this.filmContract.connect(this.deployer).issueLicense(filmId, await licensee.getAddress(), price);
        await issueTx.wait();
        console.log(`License issued successfully!`);

        console.log(`Revoking license for Film ID: ${filmId}`);
        const revokeTx = await this.filmContract.connect(this.deployer).revokeLicense(filmId);
        await revokeTx.wait();
        console.log(`License revoked successfully!`);
    }

    async listAndBuySharesTest(filmId: number, seller: Signer, buyer: Signer, price: number) {
        console.log(`Investor (${await seller.getAddress()}) listing shares for Film ID: ${filmId} at price ${price} USDT`);
        const listTx = await this.filmContract.connect(seller).listShares(filmId, price);
        await listTx.wait();
        console.log(`Shares listed successfully!`);

        console.log(`Buyer (${await buyer.getAddress()}) purchasing shares from ${await seller.getAddress()} for Film ID: ${filmId}`);
        const buyTx = await this.filmContract.connect(buyer).buyShares(filmId, await seller.getAddress(), price);
        await buyTx.wait();
        console.log(`Shares purchased successfully!`);
    }

    async listBalances(filmId: number) {
        const balances = await this.filmContract.getInvestments(filmId);
        console.log("Film Contract Balances:", balances);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();
            const metadataCID = await this.uploadMetadata("../filmfusion-contracts/files/nft-4.png");
            const filmId = await this.mintFilmNFT(metadataCID);
            await this.validateFilmExists(filmId);

            await this.investInFilm(filmId, this.investor1, 100);
            await this.investInFilm(filmId, this.investor2, 200);

            await this.withdrawInvestmentTest(filmId, this.investor1, 50);
            await this.distributeRevenueTest(filmId, 600);
            await this.claimRevenueTest(filmId, this.investor2);

            await this.issueAndRevokeLicenseTest(filmId, this.licensee, 500);
            await this.listAndBuySharesTest(filmId, this.investor2, this.buyer, 150);

            await this.listBalances(filmId);

            console.log("All tests completed successfully!");
        } catch (error) {
            console.error("Test error:", error);
            process.exit(1);
        }
    }
}

const deployer = new FilmFusionDeployer("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
deployer.run();
