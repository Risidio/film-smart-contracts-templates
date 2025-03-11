import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { any } from "hardhat/internal/core/params/argumentTypes";

describe("Licensing", function () {
    // Fixture to deploy the Licensing contract
    async function deployLicensingFixture() {
        const [owner, licensee, otherAccount] = await hre.ethers.getSigners();

        // Deploy Licensing contract
        const Licensing = await hre.ethers.getContractFactory("Licensing");
        const licensing = await Licensing.deploy();

        return { licensing, owner, licensee, otherAccount };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { licensing, owner } = await loadFixture(deployLicensingFixture);
            expect(await licensing.owner()).to.equal(owner.address);
        });
    });

    describe("Issuing Licenses", function () {
        it("Should allow the owner to issue a license with a fee", async function () {
            const { licensing, owner, licensee } = await loadFixture(deployLicensingFixture);

            const licenseFee = hre.ethers.parseEther("1"); // 1 ETH license fee
            const tx = await licensing.issueLicense(1, licensee.address, { value: licenseFee });

            const receipt = await tx.wait();

            // Find the LicenseIssued event
            const event = receipt?.logs.find((log) => {
                try {
                    return licensing.interface.parseLog(log)?.name === "LicenseIssued";
                } catch (e) {
                    return false;
                }
            });

            if (!event) {
                throw new Error("LicenseIssued event not found");
            }

            const { filmId, licensee: emittedLicensee, expiry } = licensing.interface.parseLog(event)!.args;

            // Validate emitted values
            expect(filmId).to.equal(1);
            expect(emittedLicensee).to.equal(licensee.address);

            // Allow a small margin of error in timestamp comparison (±10 sec)
            const expectedExpiry = (await hre.ethers.provider.getBlock("latest"))!.timestamp + 365 * 24 * 60 * 60;
            expect(expiry).to.be.closeTo(expectedExpiry, 10);
        });


        it("Should revert if no license fee is sent", async function () {
            const { licensing, licensee } = await loadFixture(deployLicensingFixture);

            await expect(
                licensing.issueLicense(1, licensee.address, { value: 0 })
            ).to.be.revertedWith("License fee required");
        });
    });

    describe("Revoking Licenses", function () {
        it("Should allow the owner to revoke an active license", async function () {
            const { licensing, owner, licensee } = await loadFixture(deployLicensingFixture);

            // Issue a license first
            await licensing.issueLicense(1, licensee.address, { value: hre.ethers.parseEther("1") });

            // Revoke the license
            await expect(licensing.revokeLicense(1))
                .to.emit(licensing, "LicenseRevoked")
                .withArgs(1, licensee.address);

            // Ensure the license is revoked
            const license = await licensing.filmLicenses(1);
            expect(license.licensee).to.equal(hre.ethers.ZeroAddress);
        });

        it("Should revert if there is no active license", async function () {
            const { licensing } = await loadFixture(deployLicensingFixture);

            await expect(licensing.revokeLicense(1)).to.be.revertedWith("No active license");
        });
    });
});
