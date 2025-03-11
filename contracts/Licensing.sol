// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Licensing
 * @dev Manages film licensing and royalties.
 *
 * 📌 Features:
 * - 🎟️ **Issue Film Licenses** (Allows distributors to obtain rights)
 * - 🛑 **Revoke Licenses** (Producers can revoke licenses early)
 * - 💰 **Collect Licensing Fees** (Funds go to producers)
 */
contract Licensing is Ownable {
    struct License {
        address licensee;
        uint256 expiry;
        uint256 revenue;
    }

    constructor() Ownable(msg.sender) {
    }

    mapping(uint256 => License) public filmLicenses;
    event LicenseIssued(
        uint256 filmId,
        address indexed licensee,
        uint256 expiry
    );
    event LicenseRevoked(uint256 filmId, address indexed licensee);

    /**
     * @dev 🎟️ Issues a film license.
     */
    function issueLicense(
        uint256 filmId,
        address licensee
    ) external payable onlyOwner {
        require(msg.value > 0, "License fee required");

        filmLicenses[filmId] = License({
            licensee: licensee,
            expiry: block.timestamp + 365 days,
            revenue: msg.value
        });

        emit LicenseIssued(filmId, licensee, block.timestamp + 365 days);
    }

    /**
     * @dev 🛑 Revokes an active license.
     */
    function revokeLicense(uint256 filmId) external onlyOwner {
        require(
            filmLicenses[filmId].licensee != address(0),
            "No active license"
        );

        address prevLicensee = filmLicenses[filmId].licensee;
        delete filmLicenses[filmId];

        emit LicenseRevoked(filmId, prevLicensee);
    }
}
