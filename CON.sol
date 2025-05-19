// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;



// contract address: 0xD104B06857a572e1a8d3631F467fBc83557Df9F6

// owner address: 0x3d8C2b52d2F986B880Aaa786Ff2401B2d3412a41


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ConnectVerse is ERC20, ERC20Burnable, Ownable {
    constructor(address initialOwner)
        ERC20("ConnectVerse", "CON")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}