import { ethers } from "hardhat";
import { testConnection, uploadMetadataToIPFS, uploadToIPFS } from "./upload";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying NFT contract with account: ${deployer.address}`);

    await testConnection();

    // Use the MovieNFT contract (ERC-721)
    const MovieNFT = await ethers.getContractFactory("MovieNFT");

    // Upload file (e.g., an image for the NFT) to IPFS via Pinata
    const filePath = "../filmfusion-contracts/files/nft-4.png";
    const fileCID = await uploadToIPFS(filePath);
    console.log("File CID:", fileCID);

    // Create metadata JSON linking to the uploaded file
    const metadata = {
        name: "My NFT",
        description: "My NFT",
        image: `ipfs://${fileCID}`,
        attributes: [
            { trait_type: "Genre", value: "Sci-Fi" },
            { trait_type: "Director", value: "John Doe" }
        ]
    };

    // Upload metadata to IPFS and get its CID
    const metadataCID = await uploadMetadataToIPFS(metadata);
    console.log("Metadata CID:", metadataCID);

    // Deploy the MovieNFT contract with a name and symbol
    const nftContract = await MovieNFT.deploy("MovieNFT", "MOV");
    await nftContract.waitForDeployment();
    const contractAddress = await nftContract.getAddress();
    console.log(`NFT Contract deployed at: ${contractAddress}`);

    // Mint NFT using the metadata from IPFS
    const recipient = deployer.address; // Mint to deployer, or replace with any recipient address
    const tx = await nftContract.mintNFT(recipient, `ipfs://${metadataCID}`);
    await tx.wait();
    console.log(`NFT minted successfully to ${recipient},\nTransaction hash: ${tx.hash}`);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
