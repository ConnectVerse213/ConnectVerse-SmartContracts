// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// 0xC39B9C80222eE4DD5CFCbf3D258Ac330E7B3E03D

contract Disperse is ReentrancyGuard {
    using SafeERC20 for IERC20;

    function disperseEther(address[] calldata recipients, uint256[] calldata values) external payable nonReentrant {
        require(recipients.length == values.length, "Mismatched arrays");

        for (uint256 i = 0; i < recipients.length; i++) {
            (bool sent, ) = recipients[i].call{value: values[i]}("");
            require(sent, "Failed to send Ether");
        }

        // Refund extra ether (if any)
        uint256 remaining = address(this).balance;
        if (remaining > 0) {
            (bool refunded, ) = msg.sender.call{value: remaining}("");
            require(refunded, "Refund failed");
        }
    }

    function disperseToken(IERC20 token, address[] calldata recipients, uint256[] calldata values) external nonReentrant {
        require(recipients.length == values.length, "Mismatched arrays");

        uint256 total = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }

        token.safeTransferFrom(msg.sender, address(this), total);

        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
        }
    }

    function disperseTokenSimple(IERC20 token, address[] calldata recipients, uint256[] calldata values) external nonReentrant {
        require(recipients.length == values.length, "Mismatched arrays");

        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransferFrom(msg.sender, recipients[i], values[i]);
        }
    }

    receive() external payable {}
}
