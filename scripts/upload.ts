import axios from "axios";
import fs from "fs";
import dotenv from "dotenv";
import { PinataSDK } from "pinata-web3";

dotenv.config();

const pinataApiKey = process.env.PINATA_API_KEY;
const pinataSecretApiKey = process.env.PINATA_SECRET_API_SECRET;
const pinataJWT = process.env.PINATA_JWT;
const pinataGateway = process.env.PINATA_GATEWAY;

const pinata = new PinataSDK({
    pinataJwt: pinataJWT,
    pinataGateway,
});

async function uploadToIPFS(filePath: string) {
    try {
        const blob = new Blob([fs.readFileSync(filePath)]);
        const file = new File([blob], "nft.png")
        const data = new FormData();
        data.append("file", file);

        const response = await axios.post("https://api.pinata.cloud/pinning/pinFileToIPFS", data, {
            headers: {                
                Authorization: `Bearer ${pinataJWT}`,                
            },
        });
        // const upload = await pinata.upload.file(file);
        return response.data.IpfsHash;
    } catch (error) {
        console.log(error);
    }

}

async function uploadMetadataToIPFS(metadata: any) {
    try {
        const response = await axios.post("https://api.pinata.cloud/pinning/pinJSONToIPFS", metadata, {
            headers: {
                Authorization: `Bearer ${pinataJWT}`,
            },
        });
        console.log(response.data);
        return response.data.IpfsHash;
    } catch (error) {
        console.log(error);
    }
}

const testConnection = async () => {
    try {
        const response = await axios.get("https://api.pinata.cloud/data/testAuthentication", {
            headers: {
                accept: "application/json",
                authorization: `Bearer ${pinataJWT}`,
            },
        });
        console.log(response.data);
    } catch (error) {
        console.log(error);
    }
};

export { uploadToIPFS, uploadMetadataToIPFS, testConnection };