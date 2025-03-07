// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FilmLicenseNFT is ERC721, Ownable {
    // Struct to store license details
    struct LicenseTerms {
        address filmmaker;
        uint256 royaltyPercentage;
        uint256 licenseFee;
        uint256 totalDistributionRevenue;
        bool isExclusive;
        uint256 validUntil;
    }

    // Mapping of token ID to License Terms
    mapping(uint256 => LicenseTerms) public licenseTerms;

    // Mapping to track royalties owed to filmmakers
    mapping(address => uint256) public royaltiesOwed;

    // Event declarations
    event LicenseIssued(uint256 indexed tokenId, address indexed licensee, uint256 licenseFee);
    event RoyaltyPaid(address indexed filmmaker, uint256 amount);
    event DistributionRevenueReported(uint256 indexed tokenId, uint256 revenue);
    event PaymentReceived(address indexed sender, uint256 amount);

    constructor() ERC721("FilmLicense", "FILM") Ownable(msg.sender) {}

    // Function to issue a new film license as an NFT
    function issueLicense(
        address filmmaker, 
        uint256 tokenId, 
        uint256 royaltyPercentage,
        uint256 licenseFee,
        bool isExclusive,
        uint256 validityPeriod
    ) external onlyOwner {
        require(royaltyPercentage <= 100, "Royalty percentage cannot exceed 100%");

        // Mint the license as an NFT
        _safeMint(filmmaker, tokenId);

        // Set license terms
        licenseTerms[tokenId] = LicenseTerms({
            filmmaker: filmmaker,
            royaltyPercentage: royaltyPercentage,
            licenseFee: licenseFee,
            totalDistributionRevenue: 0,
            isExclusive: isExclusive,
            validUntil: block.timestamp + validityPeriod
        });

        emit LicenseIssued(tokenId, filmmaker, licenseFee);
    }

    // Function to report distribution revenue and calculate royalties
    function reportDistributionRevenue(uint256 tokenId, uint256 revenue) external payable {
        LicenseTerms storage license = licenseTerms[tokenId];
        
        require(block.timestamp <= license.validUntil, "License has expired");
        
        // Calculate royalty amount
        uint256 royaltyAmount = (revenue * license.royaltyPercentage) / 100;
        
        // Ensure royaltyAmount is not greater than contract balance
        require(address(this).balance >= royaltyAmount, "Insufficient contract balance");

        // Update total distribution revenue
        license.totalDistributionRevenue += revenue;
        
        // Track royalties owed to the filmmaker
        royaltiesOwed[license.filmmaker] += royaltyAmount;

        emit DistributionRevenueReported(tokenId, revenue);
    }

    // Function for filmmakers to withdraw their royalties
    function withdrawRoyalties() external payable {
        uint256 amount = royaltiesOwed[msg.sender];
        require(amount > 0, "No royalties available");

        // Reset royalties owed
        royaltiesOwed[msg.sender] = 0;

        // Transfer royalties
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit RoyaltyPaid(msg.sender, amount);
    }

    // Function to check license validity
    function isLicenseValid(uint256 tokenId) external view returns (bool) {
        return block.timestamp <= licenseTerms[tokenId].validUntil;
    }

    // Override supportsInterface for ERC721
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    // Function to allow contract to receive ETH
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
