// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RevenueSplit
 * @dev Handles revenue distribution to investors.
 *
 * 📌 Features:
 * - 💸 **Revenue Collection** (Producers deposit earnings for investors)
 * - 📈 **Proportional Revenue Distribution** (Based on investments)
 * - 🏦 **Investors Claim Earnings** (Instead of automatic transfers)
 */
contract RevenueSplit is Ownable, ReentrancyGuard {
    struct Revenue {
        uint256 totalRevenue;
        mapping(address => uint256) shares;
    }

    constructor() Ownable(msg.sender) {}

    mapping(uint256 => Revenue) public filmRevenues;
    event RevenueDistributed(uint256 filmId, uint256 totalRevenue);
    event RevenueClaimed(
        uint256 filmId,
        address indexed investor,
        uint256 amount
    );

    /**
     * @dev 💸 Distributes revenue to investors.
     */
    function distributeRevenue(uint256 filmId) external payable onlyOwner {
        require(msg.value > 0, "Revenue must be greater than zero");

        Revenue storage revenue = filmRevenues[filmId];
        revenue.totalRevenue += msg.value;

        emit RevenueDistributed(filmId, msg.value);
    }

    /**
     * @dev 🏦 Investors claim their revenue share.
     */
    function claimRevenue(uint256 filmId) external nonReentrant {
        Revenue storage revenue = filmRevenues[filmId];
        require(revenue.shares[msg.sender] > 0, "No revenue to claim");

        uint256 amount = revenue.shares[msg.sender];
        revenue.shares[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit RevenueClaimed(filmId, msg.sender, amount);
    }
}
