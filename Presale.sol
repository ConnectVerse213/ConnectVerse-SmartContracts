// SPDX-License-Identifier: MIT
// 0xcACFb4e608f65bd3C456022F4ABEcc96ACEd2691

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenPresale is Ownable(msg.sender), ReentrancyGuard {
    IERC20 public token;
    uint256 public tokenRatePerETH;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public totalETHRaised;
    bool public isFinalized;
    uint256 public minETHDeposit;
    uint256 public maxETHDeposit;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public tokensClaimed;

    event TokenPurchased(address indexed buyer, uint256 amountETH, uint256 tokens);
    event Refunded(address indexed buyer, uint256 amountETH);
    event TokensClaimed(address indexed buyer, uint256 amountTokens);
    event FundsWithdrawn(address indexed owner, uint256 amountETH);
    event PresaleFinalized();

    constructor(
        address _token,
        uint256 _tokenRatePerETH,
        uint256 _daysFromNow,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _minETHDeposit,
        uint256 _maxETHDeposit
    ) {
        require(_tokenRatePerETH > 0, "Rate must be > 0");
        require(_hardCap >= _softCap, "Hard cap < soft cap");
        require(_daysFromNow > 0, "Invalid duration");
        require(_minETHDeposit <= _maxETHDeposit, "Min deposit > max deposit");

        token = IERC20(_token);
        tokenRatePerETH = _tokenRatePerETH;
        startTime = block.timestamp;
        endTime = block.timestamp + (_daysFromNow * 1 days);
        softCap = _softCap;
        hardCap = _hardCap;
        minETHDeposit = _minETHDeposit;
        maxETHDeposit = _maxETHDeposit;
    }

    modifier onlyWhileOpen() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        _;
    }

    function depositTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function buyTokens() external payable nonReentrant onlyWhileOpen {
        require(msg.value > 0, "Send ETH to buy tokens");
        require(totalETHRaised + msg.value <= hardCap, "Exceeds hard cap");
        
        uint256 newContribution = contributions[msg.sender] + msg.value;
        require(newContribution >= minETHDeposit, "Below min deposit");
        require(newContribution <= maxETHDeposit, "Exceeds max deposit");

        uint256 tokenAmount = msg.value * tokenRatePerETH;
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");

        contributions[msg.sender] = newContribution;
        totalETHRaised += msg.value;

        emit TokenPurchased(msg.sender, msg.value, tokenAmount);
    }

    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function claimTokens() external nonReentrant {
      
        require(!tokensClaimed[msg.sender], "Already claimed");
        uint256 amountETH = contributions[msg.sender];
        require(amountETH > 0, "No contribution");

        uint256 tokenAmount = amountETH * tokenRatePerETH;
        tokensClaimed[msg.sender] = true;

        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        emit TokensClaimed(msg.sender, tokenAmount);
    }

    function refund() external nonReentrant {
        require(block.timestamp > endTime, "Presale not ended");
        require(totalETHRaised < softCap, "Soft cap reached");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(msg.sender, amount);
    }

    function finalizePresale() external onlyOwner {
        require(block.timestamp > endTime, "Presale not ended");
        require(!isFinalized, "Already finalized");

        if (totalETHRaised >= softCap) {
            uint256 balance = address(this).balance;
            (bool success, ) = owner().call{value: balance}("");
            require(success, "Withdraw failed");
            emit FundsWithdrawn(owner(), balance);
        }

        isFinalized = true;
        emit PresaleFinalized();
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(isFinalized, "Presale not finalized");
        uint256 remaining = token.balanceOf(address(this));
        require(token.transfer(owner(), remaining), "Token withdrawal failed");
    }

    function getCurrentStatus() external view returns (string memory) {
        if (block.timestamp < startTime) return "Upcoming";
        if (block.timestamp >= startTime && block.timestamp <= endTime) return "Active";
        return "Ended";
    }
    
    // Helper function to check user's token allocation
    function getExpectedTokens(address user) external view returns (uint256) {
        return contributions[user] * tokenRatePerETH;
    }
}
