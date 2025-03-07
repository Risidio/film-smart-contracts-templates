// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FilmFusion Contract
 * @dev Manages Film Ownership (NFT), Investment, Revenue Sharing, Licensing, and Share Trading using native currency.
 */
contract FilmFusions is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 public _filmTokenIds;

    struct Film {
        string title;
        address producer;
        uint256 totalRaised;
        mapping(address => uint256) investments;
        address[] investors;
        mapping(address => uint256) revenueShares;
        address licensee;
        uint256 licenseExpiry;
    }

    mapping(uint256 => Film) private films;
    mapping(uint256 => uint256) public licenseRevenue;

    event FilmCreated(uint256 filmId, string title, address indexed producer);
    event InvestmentReceived(uint256 filmId, address indexed investor, uint256 amount);
    event InvestmentWithdrawn(uint256 filmId, address indexed investor, uint256 amount);
    event RevenueDistributed(uint256 filmId, uint256 totalRevenue);
    event RevenueClaimed(uint256 filmId, address indexed investor, uint256 amount);
    event LicenseIssued(uint256 filmId, address indexed licensee, uint256 expiry);
    event LicenseRevoked(uint256 filmId, address indexed licensee);
    event SharesListed(uint256 filmId, address indexed investor, uint256 price);
    event SharesSold(uint256 filmId, address indexed seller, address indexed buyer, uint256 amount);

    constructor() ERC721("FilmNFT", "FILM") Ownable(msg.sender) {}

    function _filmExists(uint256 filmId) internal view returns (bool) {
        return bytes(films[filmId].title).length > 0;
    }

    function filmExists(uint256 filmId) external view returns (bool) {
        return _filmExists(filmId);
    }

    function createFilm(string memory _title, string memory _metadataURI) external {
        _filmTokenIds++;
        uint256 newFilmId = _filmTokenIds;

        _mint(msg.sender, newFilmId);
        _setTokenURI(newFilmId, _metadataURI);

        films[newFilmId].title = _title;
        films[newFilmId].producer = msg.sender;

        emit FilmCreated(newFilmId, _title, msg.sender);
    }

    function invest(uint256 filmId) external payable nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(msg.value > 0, "Investment must be greater than zero");

        Film storage film = films[filmId];

        if (film.investments[msg.sender] == 0) {
            film.investors.push(msg.sender);
        }

        film.investments[msg.sender] += msg.value;
        film.totalRaised += msg.value;

        emit InvestmentReceived(filmId, msg.sender, msg.value);
    }

    function withdrawInvestment(uint256 filmId, uint256 amount) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.investments[msg.sender] >= amount, "Insufficient investment");

        film.investments[msg.sender] -= amount;
        film.totalRaised -= amount;

        payable(msg.sender).transfer(amount);

        if (film.investments[msg.sender] == 0) {
            for (uint256 i = 0; i < film.investors.length; i++) {
                if (film.investors[i] == msg.sender) {
                    film.investors[i] = film.investors[film.investors.length - 1];
                    film.investors.pop();
                    break;
                }
            }
        }

        emit InvestmentWithdrawn(filmId, msg.sender, amount);
    }

    function distributeRevenue(uint256 filmId) external payable onlyOwner nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(msg.value > 0, "Revenue must be greater than zero");

        Film storage film = films[filmId];

        for (uint256 i = 0; i < film.investors.length; i++) {
            address investor = film.investors[i];
            uint256 share = (film.investments[investor] * msg.value) / film.totalRaised;
            film.revenueShares[investor] += share;
        }

        emit RevenueDistributed(filmId, msg.value);
    }

    function claimRevenue(uint256 filmId) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(films[filmId].revenueShares[msg.sender] > 0, "No revenue to claim");

        uint256 amount = films[filmId].revenueShares[msg.sender];
        films[filmId].revenueShares[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit RevenueClaimed(filmId, msg.sender, amount);
    }

    function issueLicense(uint256 filmId, address licensee) external payable nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(films[filmId].producer == msg.sender, "Only producer can issue license");
        require(licensee != address(0), "Invalid licensee");
        require(msg.value > 0, "License fee must be greater than zero");

        Film storage film = films[filmId];
        require(film.licensee == address(0), "License already issued");

        film.licensee = licensee;
        film.licenseExpiry = block.timestamp + 365 days;
        licenseRevenue[filmId] += msg.value;

        emit LicenseIssued(filmId, licensee, film.licenseExpiry);
    }

    function revokeLicense(uint256 filmId) external onlyOwner {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.licensee != address(0), "No active license");

        address prevLicensee = film.licensee;
        film.licensee = address(0);
        film.licenseExpiry = 0;

        emit LicenseRevoked(filmId, prevLicensee);
    }

    function listShares(uint256 filmId, uint256 price) external {
        require(_filmExists(filmId), "Film does not exist");
        require(price > 0, "Price must be greater than zero");

        Film storage film = films[filmId];
        require(film.investments[msg.sender] > 0, "No shares to sell");

        emit SharesListed(filmId, msg.sender, price);
    }

    function buyShares(uint256 filmId, address seller) external payable nonReentrant {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.investments[seller] > 0, "Seller has no shares");
        require(msg.value > 0, "Payment must be greater than zero");

        uint256 shareAmount = film.investments[seller];

        film.investments[seller] = 0;
        film.investments[msg.sender] += shareAmount;

        payable(seller).transfer(msg.value);

        emit SharesSold(filmId, seller, msg.sender, msg.value);
    }

    function getInvestments(uint256 filmId) external view returns (address[] memory, uint256[] memory) {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        uint256 length = film.investors.length;
        uint256[] memory amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            amounts[i] = film.investments[film.investors[i]];
        }
        return (film.investors, amounts);
    }
}
