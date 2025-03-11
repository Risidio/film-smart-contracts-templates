// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StreamingPayouts is Ownable, ReentrancyGuard {
    mapping(uint256 => uint256) public filmStreamingRevenue;

    event StreamingRevenueReceived(uint256 filmId, uint256 amount);
    event StreamingPayoutDistributed(uint256 filmId, uint256 totalAmount);

    constructor() Ownable(msg.sender) {
    }
    
    /**
     * @dev Collects micropayments from streaming.
     */
    function collectStreamingRevenue(uint256 filmId) external payable {
        require(msg.value > 0, "Must send ETH for streaming");
        filmStreamingRevenue[filmId] += msg.value;

        emit StreamingRevenueReceived(filmId, msg.value);
    }

    /**
     * @dev Distributes streaming revenue to rights holders.
     */
    function distributeStreamingPayout(uint256 filmId) external onlyOwner {
        require(filmStreamingRevenue[filmId] > 0, "No revenue to distribute");

        uint256 totalAmount = filmStreamingRevenue[filmId];
        filmStreamingRevenue[filmId] = 0;
        payable(owner()).transfer(totalAmount);

        emit StreamingPayoutDistributed(filmId, totalAmount);
    }
}