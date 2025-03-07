// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FilmFusion Contract
 * @dev Manages Film Ownership (NFT), Investment, Revenue Sharing, Licensing, and Share Trading
 */
contract FilmFusion is ERC721URIStorage, Ownable, ReentrancyGuard {
    IERC20 public usdt;
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
    mapping(uint256 => uint256) public licenseRevenue; // Track license revenue per film

    event FilmCreated(uint256 filmId, string title, address indexed producer);
    event InvestmentReceived(uint256 filmId, address indexed investor, uint256 amount);
    event InvestmentWithdrawn(uint256 filmId, address indexed investor, uint256 amount);
    event RevenueDistributed(uint256 filmId, uint256 totalRevenue);
    event RevenueClaimed(uint256 filmId, address indexed investor, uint256 amount);
    event LicenseIssued(uint256 filmId, address indexed licensee, uint256 expiry);
    event LicenseRevoked(uint256 filmId, address indexed licensee);
    event SharesListed(uint256 filmId, address indexed investor, uint256 price);
    event SharesSold(uint256 filmId, address indexed seller, address indexed buyer, uint256 amount);

    constructor(address _usdt) ERC721("FilmNFT", "FILM") Ownable(msg.sender) {
        usdt = IERC20(_usdt);
    }

    /**
     * @dev Checks if a film exists.
     */
    function _filmExists(uint256 filmId) internal view returns (bool) {
        return bytes(films[filmId].title).length > 0;
    }

    /**
     * @dev Public function to check if a film exists.
     */
    function filmExists(uint256 filmId) external view returns (bool) {
        return _filmExists(filmId);
    }

    /**
     * @dev Creates a new film NFT and registers it in the system.
     */
    function createFilm(string memory _title, string memory _metadataURI) external {
        _filmTokenIds++;
        uint256 newFilmId = _filmTokenIds; // Unique film ID

        _mint(msg.sender, newFilmId);
        _setTokenURI(newFilmId, _metadataURI);

        films[newFilmId].title = _title;
        films[newFilmId].producer = msg.sender;

        emit FilmCreated(newFilmId, _title, msg.sender);
    }

    /**
     * @dev Investors must approve USDT spending before investing.
     */
    function invest(uint256 filmId, uint256 amount) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(amount > 0, "Investment must be greater than zero");

        Film storage film = films[filmId];

        // Use low-level call for USDT.transferFrom
        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(
                usdt.transferFrom.selector,
                msg.sender,
                address(this),
                amount
            )
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        if (film.investments[msg.sender] == 0) {
            film.investors.push(msg.sender);
        }
        film.investments[msg.sender] += amount;
        film.totalRaised += amount;

        emit InvestmentReceived(filmId, msg.sender, amount);
    }

    /**
     * @dev Withdraw investment from a film.
     */
    function withdrawInvestment(uint256 filmId, uint256 amount) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.investments[msg.sender] >= amount, "Insufficient investment");

        film.investments[msg.sender] -= amount;
        film.totalRaised -= amount;
        
        // Use low-level call for USDT.transfer
        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(usdt.transfer.selector, msg.sender, amount)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        // Remove investor if they withdraw everything
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

    /**
     * @dev Owner triggers yearly revenue distribution.
     */
    function distributeRevenue(uint256 filmId, uint256 totalRevenue) external onlyOwner nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(totalRevenue > 0, "Revenue must be greater than zero");

        // Low-level call for USDT.transferFrom for revenue deposit
        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(usdt.transferFrom.selector, msg.sender, address(this), totalRevenue)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        Film storage film = films[filmId];
        for (uint256 i = 0; i < film.investors.length; i++) {
            address investor = film.investors[i];
            uint256 share = (film.investments[investor] * totalRevenue) / film.totalRaised;
            film.revenueShares[investor] += share;

            // Low-level call for USDT.transfer in loop
            (bool successTransfer, bytes memory returndataTransfer) = address(usdt).call(
                abi.encodeWithSelector(usdt.transfer.selector, investor, share)
            );
            require(successTransfer && (returndataTransfer.length == 0 || abi.decode(returndataTransfer, (bool))), "USDT transfer failed");
        }
        emit RevenueDistributed(filmId, totalRevenue);
    }

    /**
     * @dev Investors claim their revenue instead of automatic transfer.
     */
    function claimRevenue(uint256 filmId) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(films[filmId].revenueShares[msg.sender] > 0, "No revenue to claim");

        uint256 amount = films[filmId].revenueShares[msg.sender];
        films[filmId].revenueShares[msg.sender] = 0;

        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(usdt.transfer.selector, msg.sender, amount)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        emit RevenueClaimed(filmId, msg.sender, amount);
    }

    /**
     * @dev Issue an exclusive license to a distributor for 1 year.
     */
    function issueLicense(uint256 filmId, address licensee, uint256 price) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");
        require(films[filmId].producer == msg.sender, "Only producer can issue license");
        require(licensee != address(0), "Invalid licensee");

        Film storage film = films[filmId];
        require(film.licensee == address(0), "License already issued");

        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(usdt.transferFrom.selector, licensee, address(this), price)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        film.licensee = licensee;
        film.licenseExpiry = block.timestamp + 365 days;
        licenseRevenue[filmId] += price;

        emit LicenseIssued(filmId, licensee, film.licenseExpiry);
    }

    /**
     * @dev Revoke an active license before expiry.
     */
    function revokeLicense(uint256 filmId) external onlyOwner {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.licensee != address(0), "No active license");

        address prevLicensee = film.licensee;
        film.licensee = address(0);
        film.licenseExpiry = 0;

        emit LicenseRevoked(filmId, prevLicensee);
    }

    /**
     * @dev Investors can list their shares for sale at a fixed price.
     */
    function listShares(uint256 filmId, uint256 price) external {
        require(_filmExists(filmId), "Film does not exist");
        require(price > 0, "Price must be greater than zero");

        Film storage film = films[filmId];
        require(film.investments[msg.sender] > 0, "No shares to sell");

        emit SharesListed(filmId, msg.sender, price);
    }

    /**
     * @dev Buy investment shares from another investor.
     */
    function buyShares(uint256 filmId, address seller, uint256 price) external nonReentrant {
        require(_filmExists(filmId), "Film does not exist");

        Film storage film = films[filmId];
        require(film.investments[seller] > 0, "Seller has no shares");

        (bool success, bytes memory returndata) = address(usdt).call(
            abi.encodeWithSelector(usdt.transferFrom.selector, msg.sender, seller, price)
        );
        require(success && (returndata.length == 0 || abi.decode(returndata, (bool))), "USDT transfer failed");

        uint256 shareAmount = film.investments[seller];
        film.investments[seller] = 0;
        film.investments[msg.sender] += shareAmount;

        emit SharesSold(filmId, seller, msg.sender, price);
    }

    /**
     * @dev Retrieve all investments for a given film.
     * Returns an array of investor addresses and their corresponding investment amounts.
     */
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
