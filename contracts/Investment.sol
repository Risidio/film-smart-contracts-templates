// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Investment
 * @dev Manages film crowdfunding, tokenized shares, and escrowed funds.
 * 
 * 📌 Features:
 * - 💰 **Tokenized Shares Issued** (Investors get shares based on contribution)
 * - 🔒 **Escrowed Funds** (Locked until funding goal is met)
 * - 🚀 **Automatic Fund Release** (To the Film Production Wallet)
 */
contract Investment is Ownable, ReentrancyGuard {
    struct FilmInvestment {
        uint256 totalRaised;
        uint256 fundingGoal;
        bool goalReached;
        address productionWallet;
        mapping(address => uint256) investments;
        address[] investors;
    }

    constructor () Ownable(msg.sender) {}
    
    mapping(uint256 => FilmInvestment) public filmInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorShares;

    event InvestmentReceived(uint256 filmId, address indexed investor, uint256 amount);
    event InvestmentWithdrawn(uint256 filmId, address indexed investor, uint256 amount);
    event FundingGoalReached(uint256 filmId, uint256 totalRaised);
    event FundsReleased(uint256 filmId, uint256 totalAmount, address productionWallet);

    /**
     * @dev 💰 Creates a new film investment opportunity with a funding goal.
     */
    function createFilmInvestment(uint256 filmId, uint256 goal, address productionWallet) external onlyOwner {
        require(goal > 0, "Funding goal must be greater than zero");
        require(productionWallet != address(0), "Invalid production wallet");

        FilmInvestment storage film = filmInvestments[filmId];
        require(film.fundingGoal == 0, "Film investment already exists");

        film.fundingGoal = goal;
        film.productionWallet = productionWallet;
    }

    /**
     * @dev 💰 Investors contribute funds to a film.
     */
    function invest(uint256 filmId) external payable nonReentrant {
        require(msg.value > 0, "Investment must be greater than zero");

        FilmInvestment storage film = filmInvestments[filmId];
        require(film.fundingGoal > 0, "Film investment does not exist");
        require(!film.goalReached, "Funding goal already reached");

        if (film.investments[msg.sender] == 0) {
            film.investors.push(msg.sender);
        }

        film.investments[msg.sender] += msg.value;
        film.totalRaised += msg.value;

        // Calculate investor shares as a percentage of total funding goal
        investorShares[filmId][msg.sender] = (film.investments[msg.sender] * 100) / film.fundingGoal;

        emit InvestmentReceived(filmId, msg.sender, msg.value);

        // Check if funding goal is reached
        if (film.totalRaised >= film.fundingGoal) {
            film.goalReached = true;
            emit FundingGoalReached(filmId, film.totalRaised);
            releaseFunds(filmId);
        }
    }

    /**
     * @dev 🔄 Withdraw investment if funding goal is not yet met.
     */
    function withdrawInvestment(uint256 filmId, uint256 amount) external nonReentrant {
        FilmInvestment storage film = filmInvestments[filmId];
        require(!film.goalReached, "Cannot withdraw after funding goal is reached");
        require(film.investments[msg.sender] >= amount, "Insufficient balance");

        film.investments[msg.sender] -= amount;
        film.totalRaised -= amount;
        investorShares[filmId][msg.sender] = (film.investments[msg.sender] * 100) / film.fundingGoal;

        payable(msg.sender).transfer(amount);
        emit InvestmentWithdrawn(filmId, msg.sender, amount);
    }

    /**
     * @dev 🚀 Releases funds to the production wallet when the funding goal is reached.
     */
    function releaseFunds(uint256 filmId) internal {
        FilmInvestment storage film = filmInvestments[filmId];
        require(film.goalReached, "Funding goal not yet reached");
        require(film.productionWallet != address(0), "Production wallet not set");

        uint256 totalAmount = film.totalRaised;
        film.totalRaised = 0;

        payable(film.productionWallet).transfer(totalAmount);
        emit FundsReleased(filmId, totalAmount, film.productionWallet);
    }

    /**
     * @dev 📊 Get total investment.
     */
    function getTotalInvestment(uint256 filmId) external view returns (uint256) {
        return filmInvestments[filmId].totalRaised;
    }

    /**
     * @dev 📜 Get an investor's share percentage for a given film.
     */
    function getInvestorShares(uint256 filmId, address investor) external view returns (uint256) {
        return investorShares[filmId][investor];
    }
}
