require("dotenv").config();
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");
const path = require("path");

const PINATA_JWT = process.env.PINATA_JWT;

async function uploadFileToIPFS() {
  const filePath = path.join(
    __dirname,
    process.argv[2] || "../assets/Risidio_Logo.jpeg"
  );
  const formData = new FormData();
  formData.append("file", fs.createReadStream(filePath));

  const options = JSON.stringify({ cidVersion: 1 });
  formData.append("pinataOptions", options);

  try {
    const response = await axios.post(
      "https://api.pinata.cloud/pinning/pinFileToIPFS",
      formData,
      {
        headers: {
          Authorization: `Bearer ${PINATA_JWT}`,
          ...formData.getHeaders(),
        },
      }
    );
    console.log("Image uploaded:", `ipfs://${response.data.IpfsHash}`);
    return `ipfs://${response.data.IpfsHash}`;
  } catch (error) {
    console.error("File upload failed:", error);

    return null;
  }
}

async function uploadMetadataToIPFS(imageUri) {
  const metadata = {
    name: "WebNFT",
    description: "A unique NFT on Hedera",
    image: imageUri,
  };

  try {
    const response = await axios.post(
      "https://api.pinata.cloud/pinning/pinJSONToIPFS",
      metadata,
      { headers: { Authorization: `Bearer ${PINATA_JWT}` } }
    );
    console.log("Metadata uploaded:", `ipfs://${response.data.IpfsHash}`);
    return `ipfs://${response.data.IpfsHash}`;
  } catch (error) {
    console.error("Metadata upload failed:", error);
    return null;
  }
}

async function uploadToIPFS() {
  const imageUri = await uploadFileToIPFS();
  if (imageUri) {
    const metadataUri = await uploadMetadataToIPFS(imageUri);
    console.log("Final metadata URI:", metadataUri);
  } else {
    console.error("File upload failed. Metadata upload skipped.");
  }
}

uploadToIPFS();
