// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BaseFilmContract
 * @dev A reusable contract template for FilmFusion AI agent to generate contracts dynamically.
 */
contract BaseFilmContract is Ownable, ReentrancyGuard {
    IERC20 public usdt;
    string public filmId;
    string public title;
    address public producer;    
    uint256 public totalRaised;
    mapping(address => uint256) public investments;
    mapping(address => uint256) public revenueShares;
    address[] public investors;
    address public initialOwner;

    event InvestmentReceived(address indexed investor, uint256 amount);
    event RevenueDistributed(uint256 amount);
    
    constructor(
        string memory _filmId,
        string memory _title,
        address _producer,
        address _usdt,
        address _initialOwner
    ) Ownable(_initialOwner) {
        filmId = _filmId;
        title = _title;
        producer = _producer;
        usdt = IERC20(_usdt);
        initialOwner = _initialOwner;
    }

    function invest(uint256 amount) external nonReentrant {
        require(amount > 0, "Investment must be greater than zero");
        require(usdt.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        
        if (investments[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        investments[msg.sender] += amount;
        totalRaised += amount;
        
        emit InvestmentReceived(msg.sender, amount);
    }

    function calculateRevenueShares(uint256 totalRevenue) internal {
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 share = (investments[investor] * totalRevenue) / totalRaised;
            revenueShares[investor] = share;
        }
    }
    
    function distributeRevenue(uint256 totalRevenue) external onlyOwner nonReentrant {
        require(totalRevenue > 0, "Revenue must be greater than zero");
        require(usdt.transferFrom(msg.sender, address(this), totalRevenue), "USDT transfer failed");
        
        calculateRevenueShares(totalRevenue);

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 share = revenueShares[investor];
            if (share > 0) {
                require(usdt.transfer(investor, share), "USDT transfer failed");
            }
        }
        
        emit RevenueDistributed(totalRevenue);
    }
}
