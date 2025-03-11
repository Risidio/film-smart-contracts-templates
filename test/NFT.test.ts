import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("FilmNFT", function () {
    // 📌 Fixture to deploy the FilmNFT contract
    async function deployFilmNFTFixture() {
        const [owner, newOwner, director, writer, investor, otherAccount] = await hre.ethers.getSigners();

        // Deploy FilmNFT contract
        const FilmNFT = await hre.ethers.getContractFactory("FilmNFT");
        const filmNFT = await FilmNFT.deploy();

        return { filmNFT, owner, newOwner, director, writer, investor, otherAccount };
    }

    describe("Deployment", function () {
        it("Should set the correct contract owner", async function () {
            const { filmNFT, owner } = await loadFixture(deployFilmNFTFixture);
            expect(await filmNFT.owner()).to.equal(owner.address);
        });
    });

    describe("Minting Film NFTs", function () {
        it("Should allow the owner to mint a film NFT with revenue shares", async function () {
            const { filmNFT, owner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);
            
            const investors = [investor.address];
            const tx = await filmNFT.createFilm("Sci-Fi Film", "ipfs://metadata-uri", "ipfs://asset-uri", director.address, writer.address, investors);
            const receipt = await tx.wait();

            // Find the FilmCreated event
            const event = receipt?.logs.find((log) => {
                try {
                    return filmNFT.interface.parseLog(log)?.name === "FilmCreated";
                } catch (e) {
                    return false;
                }
            });

            if (!event) {
                throw new Error("FilmCreated event not found");
            }

            const { filmId, title, producer } = filmNFT.interface.parseLog(event)!.args;

            // Validate emitted values
            expect(filmId).to.equal(1);
            expect(title).to.equal("Sci-Fi Film");
            expect(producer).to.equal(owner.address);

            // Verify stored film details
            const filmDetails = await filmNFT.getFilmDetails(filmId);
            expect(filmDetails[0]).to.equal("Sci-Fi Film");
            expect(filmDetails[1]).to.equal(owner.address);
        });

        it("Should revert if a non-owner tries to mint an NFT", async function () {
            const { filmNFT, director, writer, investor, otherAccount } = await loadFixture(deployFilmNFTFixture);
            const investors = [investor.address];

            await expect(
                filmNFT.connect(otherAccount).createFilm("Unauthorized Film", "ipfs://unauthorized-metadata", "ipfs://asset-uri", director.address, writer.address, investors)
            ).to.be.reverted;
        });
    });

    describe("Setting and Retrieving Film Prices", function () {
        it("Should allow the owner to set a price for a film", async function () {
            const { filmNFT, owner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Sci-Fi Film", "ipfs://metadata-uri", "ipfs://asset-uri", director.address, writer.address, investors);

            await filmNFT.setFilmPrice(1, hre.ethers.parseEther("2"));

            const price = await filmNFT.filmPrices(1);
            expect(price).to.equal(hre.ethers.parseEther("2"));
        });

        it("Should revert if a non-owner tries to set a price", async function () {
            const { filmNFT, director, writer, investor, otherAccount } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Sci-Fi Film", "ipfs://metadata-uri", "ipfs://asset-uri", director.address, writer.address, investors);

            await expect(
                filmNFT.connect(otherAccount).setFilmPrice(1, hre.ethers.parseEther("2"))
            ).to.be.reverted;
        });
    });

    describe("Transferring Film Ownership", function () {
        it("Should allow a buyer to purchase and transfer film ownership", async function () {
            const { filmNFT, owner, newOwner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Transferable Film", "ipfs://transfer-metadata", "ipfs://asset-uri", director.address, writer.address, investors);

            // Set a price
            await filmNFT.setFilmPrice(1, hre.ethers.parseEther("2"));

            // Buyer purchases the NFT
            await filmNFT.connect(newOwner).transferFilmOwnership(1, newOwner.address, { value: hre.ethers.parseEther("2") });

            // Verify new owner
            expect(await filmNFT.ownerOf(1)).to.equal(newOwner.address);
        });

        it("Should revert if payment is insufficient", async function () {
            const { filmNFT, owner, newOwner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Underpriced Film", "ipfs://transfer-metadata", "ipfs://asset-uri", director.address, writer.address, investors);

            await filmNFT.setFilmPrice(1, hre.ethers.parseEther("2"));

            await expect(
                filmNFT.connect(newOwner).transferFilmOwnership(1, newOwner.address, { value: hre.ethers.parseEther("1") })
            ).to.be.revertedWith("Insufficient payment");
        });

        it("Should revert if a non-buyer tries to initiate a transfer", async function () {
            const { filmNFT, owner, newOwner, otherAccount, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Unauthorized Transfer", "ipfs://transfer-metadata", "ipfs://asset-uri", director.address, writer.address, investors);

            await filmNFT.setFilmPrice(1, hre.ethers.parseEther("2"));

            await expect(
                filmNFT.connect(otherAccount).transferFilmOwnership(1, newOwner.address, { value: hre.ethers.parseEther("2") })
            ).to.be.reverted;
        });
    });

    describe("Retrieving Revenue Share", function () {
        it("Should return the correct revenue share", async function () {
            const { filmNFT, owner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Revenue Film", "ipfs://metadata-uri", "ipfs://asset-uri", director.address, writer.address, investors);

            const [producerShare, investorShare, directorShare, writerShare] = await filmNFT.getRevenueShare(1);

            expect(producerShare).to.equal(40);
            expect(investorShare).to.equal(30);
            expect(directorShare).to.equal(20);
            expect(writerShare).to.equal(10);
        });
    });

    describe("Retrieving Film Metadata", function () {
        it("Should return the correct film metadata", async function () {
            const { filmNFT, owner, director, writer, investor } = await loadFixture(deployFilmNFTFixture);

            const investors = [investor.address];
            await filmNFT.createFilm("Metadata Test", "ipfs://metadata-test", "ipfs://asset-uri", director.address, writer.address, investors);

            const filmDetails = await filmNFT.getFilmDetails(1);

            expect(filmDetails[0]).to.equal("Metadata Test");
            expect(filmDetails[1]).to.equal(owner.address);
        });
    });
});
