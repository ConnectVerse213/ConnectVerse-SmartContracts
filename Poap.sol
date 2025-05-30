// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PoapNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("POAP Certificate", "POAP") {
        tokenCounter = 0;
    }

    function mint(address to, string memory tokenURI) public onlyOwner {
        uint256 newTokenId = tokenCounter;
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenCounter++;
    }
}
