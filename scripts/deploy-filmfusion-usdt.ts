import { ethers } from "hardhat";
import { JsonRpcProvider } from "ethers";
import { testConnection, uploadMetadataToIPFS, uploadToIPFS } from "./upload";
import { EventLog } from "ethers";
import { Wallet } from "@hashgraph/sdk";
import dotenv from "dotenv"

dotenv.config();

class FilmFusionDeployer {
    private provider: any
    private deployer: any;
    private investor1: any;
    private investor2: any;
    private licensee: any;
    private buyer: any;
    private filmContract: any;
    private usdtContract: any;
    private usdtAddress: string;

    constructor(usdtAddress: string) {
        this.usdtAddress = usdtAddress;
    }

    async initialize() {
        [this.deployer, this.investor1, this.investor2, this.licensee, this.buyer] = await ethers.getSigners(); 
        // console.log("Hedera RPC URL:", process.env.HEDERA_RPC_URL);
        // this.provider = new JsonRpcProvider(process.env.HEDERA_RPC_URL);   
        // console.log(this.provider) 
        // console.log("Deployer Private Key:", process.env.HEDERA_PRIVATE_KEY);    
        // this.deployer = new Wallet(process.env.PRIVATE_KEY!, this.provider);
        // this.investor1 = this.deployer
        // this.investor2 = this.deployer
        // this.licensee = this.deployer
        // this.buyer = this.deployer
        console.log("Deployer:", this.deployer.address);
        console.log("Investor1:", this.investor1.address);
        console.log("Investor2:", this.investor2.address);
        console.log("Licensee:", this.licensee.address);
        console.log("Buyer:", this.buyer.address);
        await testConnection();
        
        const usdtAbi = [
            "function approve(address spender, uint256 amount) public returns (bool)",
            "function transferFrom(address sender, address recipient, uint256 amount) public returns (bool)",
            "function transfer(address recipient, uint256 amount) public returns (bool)",
            "function balanceOf(address account) public view returns (uint256)",
            "function allowance(address owner, address spender) public view returns (uint256)"
        ];
        this.usdtContract = new ethers.Contract(this.usdtAddress, usdtAbi, this.deployer);
    }

    async deployContract() {
        const FilmFusion = await ethers.getContractFactory("FilmFusion");
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
        const mintTx = await this.filmContract.createFilm(
            "Sci-Fi Film",
            `ipfs://${metadataCID}`
        );
        const receipt = await mintTx.wait();
        
        const filmCreatedEvent = receipt.logs.find((log: any) => {
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

    async investInFilm(filmId: number, investor: any, amount: any) {
        console.log(`Investor (${investor.address}) investing ${amount} USDT in Film ID: ${filmId}`);
        const contractAddress = await this.filmContract.getAddress();
        console.log("FilmFusion Contract Address:", contractAddress);
        
        const usdtAllowanceTx = await this.usdtContract.connect(investor).approve(contractAddress, amount);
        await usdtAllowanceTx.wait();
        console.log("Approved FilmFusion contract to spend USDT on behalf of investor:", investor.address);

        const investTx = await this.filmContract.connect(investor).invest(filmId, amount);
        await investTx.wait();
        console.log(`Investor (${investor.address}) invested ${amount} USDT in Film ID: ${filmId}`);
    }

    async withdrawInvestmentTest(filmId: number, investor: any, amount: any) {
        console.log(`Investor (${investor.address}) attempting to withdraw ${amount} USDT from Film ID: ${filmId}`);
        const withdrawTx = await this.filmContract.connect(investor).withdrawInvestment(filmId, amount);
        await withdrawTx.wait();
        console.log(`Investor (${investor.address}) successfully withdrew ${amount} USDT from Film ID: ${filmId}`);
    }

    async distributeRevenueTest(filmId: number, totalRevenue: any) {
        console.log(`Owner distributing ${totalRevenue} USDT revenue for Film ID: ${filmId}`);
        const distributeTx = await this.filmContract.connect(this.deployer).distributeRevenue(filmId, totalRevenue);
        await distributeTx.wait();
        console.log(`Revenue of ${totalRevenue} USDT distributed for Film ID: ${filmId}`);
    }

    async claimRevenueTest(filmId: number, investor: any) {
        console.log(`Investor (${investor.address}) claiming revenue for Film ID: ${filmId}`);
        const claimTx = await this.filmContract.connect(investor).claimRevenue(filmId);
        await claimTx.wait();
        console.log(`Investor (${investor.address}) claimed revenue successfully for Film ID: ${filmId}`);
    }

    async issueAndRevokeLicenseTest(filmId: number, licensee: any, price: any) {
        console.log(`Issuing license for Film ID: ${filmId} to ${licensee.address} for price ${price} USDT`);
        const issueTx = await this.filmContract.connect(this.deployer).issueLicense(filmId, licensee.address, price);
        await issueTx.wait();
        console.log(`License issued to ${licensee.address} for Film ID: ${filmId}`);

        console.log(`Revoking license for Film ID: ${filmId}`);
        const revokeTx = await this.filmContract.connect(this.deployer).revokeLicense(filmId);
        await revokeTx.wait();
        console.log(`License revoked for Film ID: ${filmId}`);
    }

    async listAndBuySharesTest(filmId: number, seller: any, buyer: any, price: any) {
        console.log(`Investor (${seller.address}) listing shares for Film ID: ${filmId} at price ${price} USDT`);
        const listTx = await this.filmContract.connect(seller).listShares(filmId, price);
        await listTx.wait();
        console.log(`Shares listed by ${seller.address}`);

        console.log(`Buyer (${buyer.address}) buying shares from ${seller.address} for Film ID: ${filmId}`);
        const buyTx = await this.filmContract.connect(buyer).buyShares(filmId, seller.address, price);
        await buyTx.wait();
        console.log(`Shares purchased by ${buyer.address} from ${seller.address}`);
    }
    
    async listBalances(filmId: number) {
        const filmContractAddress = await this.filmContract.getAddress();
        const balances = await this.filmContract.getInvestments(filmId)
        console.log("Film Contract USDT Balances:", balances);
    }

    async run() {
        try {
            await this.initialize();
            await this.deployContract();
            const metadataCID = await this.uploadMetadata("../filmfusion-contracts/files/nft-4.png");
            const filmId = await this.mintFilmNFT(metadataCID);
            await this.validateFilmExists(filmId);

            // Test investments
            const investAmount1 = 100;
            const investAmount2 = 200;
            await this.investInFilm(filmId, this.investor1, investAmount1);
            await this.investInFilm(filmId, this.investor2, investAmount2);

            // Test withdrawal: investor1 withdraws 50 USDT
            const withdrawAmount = 50;
            await this.withdrawInvestmentTest(filmId, this.investor1, withdrawAmount);

            // Test revenue distribution: Owner distributes 600 USDT
            const totalRevenue = 600;
            // await this.distributeRevenueTest(filmId, totalRevenue);

            // Test revenue claiming: investor2 claims revenue
            // await this.claimRevenueTest(filmId, this.investor2);

            // Test license issuance and revocation: licensee with a fee of 500 USDT
            const licensePrice = 500;
            await this.issueAndRevokeLicenseTest(filmId, this.licensee, licensePrice);

            // Test listing and buying shares: investor2 lists shares for 150 USDT; buyer purchases them
            const sharePrice = 150;
            await this.listAndBuySharesTest(filmId, this.investor2, this.buyer, sharePrice);

            // List all USDT balances at the end of tests
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
