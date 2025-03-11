import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Investment", function () {
    async function deployInvestmentFixture() {
        const [owner, investor1, investor2, productionWallet, otherAccount] = await hre.ethers.getSigners();

        // Deploy Investment contract
        const Investment = await hre.ethers.getContractFactory("Investment");
        const investment = await Investment.deploy();

        return { investment, owner, investor1, investor2, productionWallet, otherAccount };
    }

    describe("Deployment", function () {
        it("Should set the right contract owner", async function () {
            const { investment, owner } = await loadFixture(deployInvestmentFixture);
            expect(await investment.owner()).to.equal(owner.address);
        });
    });

    describe("Creating Film Investment", function () {
        it("Should allow owner to create a film investment opportunity", async function () {
            const { investment, owner, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("10");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);

            const filmInvestment = await investment.filmInvestments(filmId);
            expect(filmInvestment.fundingGoal).to.equal(fundingGoal);
            expect(filmInvestment.productionWallet).to.equal(productionWallet.address);
        });

        it("Should prevent non-owners from creating a film investment", async function () {
            const { investment, investor1, productionWallet } = await loadFixture(deployInvestmentFixture);
            await expect(
                investment.connect(investor1).createFilmInvestment(1, hre.ethers.parseEther("10"), productionWallet.address)
            ).to.be.reverted;
        });
    });

    describe("Investments", function () {
        it("Should allow users to invest and receive shares", async function () {
            const { investment, investor1, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("10");
            const investAmount = hre.ethers.parseEther("2");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);

            await expect(investment.connect(investor1).invest(filmId, { value: investAmount }))
                .to.emit(investment, "InvestmentReceived")
                .withArgs(filmId, investor1.address, investAmount);

            expect(await investment.getTotalInvestment(filmId)).to.equal(investAmount);

            const investorShares = await investment.getInvestorShares(filmId, investor1.address);
            expect(investorShares).to.equal(20); // 2/10 * 100 = 20%
        });

        it("Should prevent zero-value investments", async function () {
            const { investment, investor1 } = await loadFixture(deployInvestmentFixture);
            await expect(investment.connect(investor1).invest(1, { value: 0 }))
                .to.be.reverted;
        });

        it("Should prevent investments if funding goal is already reached", async function () {
            const { investment, investor1, investor2, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("5");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);

            await investment.connect(investor1).invest(filmId, { value: hre.ethers.parseEther("3") });
            await investment.connect(investor2).invest(filmId, { value: hre.ethers.parseEther("2") });

            await expect(
                investment.connect(investor1).invest(filmId, { value: hre.ethers.parseEther("1") })
            ).to.be.reverted;
        });

        it("Should trigger funding goal event and release funds automatically", async function () {
            const { investment, investor1, investor2, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("5");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);

            await expect(investment.connect(investor1).invest(filmId, { value: hre.ethers.parseEther("3") }))
                .to.emit(investment, "InvestmentReceived");

            await expect(investment.connect(investor2).invest(filmId, { value: hre.ethers.parseEther("2") }))
                .to.emit(investment, "FundingGoalReached")
                .withArgs(filmId, fundingGoal);

            // Verify funds are transferred to production wallet
            const prodBalance = await hre.ethers.provider.getBalance(productionWallet.address)
            console.log(prodBalance, fundingGoal)
            expect(prodBalance).to.equal(fundingGoal);
        });
    });

    describe("Withdrawals", function () {
        it("Should allow users to withdraw their investment before goal is met", async function () {
            const { investment, investor1, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("10");
            const investAmount = hre.ethers.parseEther("2");
            const withdrawAmount = hre.ethers.parseEther("1");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);
            await investment.connect(investor1).invest(filmId, { value: investAmount });

            await expect(investment.connect(investor1).withdrawInvestment(filmId, withdrawAmount))
                .to.emit(investment, "InvestmentWithdrawn")
                .withArgs(filmId, investor1.address, withdrawAmount);

            // Ensure balance is updated
            expect(await investment.getTotalInvestment(filmId)).to.equal(investAmount - withdrawAmount);

            // Ensure shares are updated
            const updatedShares = await investment.getInvestorShares(filmId, investor1.address);
            expect(updatedShares).to.equal(10); // Remaining 1/10 * 100
        });

        it("Should prevent withdrawing more than invested", async function () {
            const { investment, investor1, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("10");
            const investAmount = hre.ethers.parseEther("1");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);
            await investment.connect(investor1).invest(filmId, { value: investAmount });

            await expect(
                investment.connect(investor1).withdrawInvestment(filmId, hre.ethers.parseEther("2"))
            ).to.be.revertedWith("Insufficient balance");
        });

        it("Should prevent withdrawals after funding goal is reached", async function () {
            const { investment, investor1, investor2, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("5");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);
            await investment.connect(investor1).invest(filmId, { value: hre.ethers.parseEther("3") });
            await investment.connect(investor2).invest(filmId, { value: hre.ethers.parseEther("2") });

            await expect(
                investment.connect(investor1).withdrawInvestment(filmId, hre.ethers.parseEther("1"))
            ).to.be.reverted;
        });
    });

    describe("Total Investment & Shares", function () {
        it("Should correctly track total investment and investor shares", async function () {
            const { investment, investor1, investor2, productionWallet } = await loadFixture(deployInvestmentFixture);
            const filmId = 1;
            const fundingGoal = hre.ethers.parseEther("10");

            await investment.createFilmInvestment(filmId, fundingGoal, productionWallet.address);

            await investment.connect(investor1).invest(filmId, { value: hre.ethers.parseEther("3") });
            await investment.connect(investor2).invest(filmId, { value: hre.ethers.parseEther("2") });

            expect(await investment.getTotalInvestment(filmId)).to.equal(hre.ethers.parseEther("5"));
            expect(await investment.getInvestorShares(filmId, investor1.address)).to.equal(30);
            expect(await investment.getInvestorShares(filmId, investor2.address)).to.equal(20);
        });
    });
});
