// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CRecy.sol";

contract Vendor is Ownable, ReentrancyGuard, Pausable {
    CRecy _cRecy;

    // PRICE
    uint256 public priceCRecy;

    //TOTAL SOLD
    uint256 public totalSold;

    //Total MWP per address

    mapping(address => uint256) public purchaseOrder;

    event Pause();
    event unPause();
    event BuycRecy(address account, uint256 Celo, uint256 cRecy);

    error FailWithdraw(uint256 ownerBalance, address sender);
    error FailBuyTokens(address account, uint256 value);
    error InsufficientTokens(uint256 vendorBalance, uint256 cRecy);

    constructor(address mwpAddress) {
        _cRecy = CRecy(mwpAddress);
        setPricecRecy(7 * 10**17);
    }

    function pause() public onlyOwner {
        _pause();
        emit Pause();
    }

    function unpause() public onlyOwner {
        _unpause();
        emit unPause();
    }

    function setPricecRecy(uint256 _price) public onlyOwner {
        priceCRecy = _price;
    }

    function TokensPerCelo() public view returns (uint256) {
        return 10**36 / priceCRecy;
    }

    function amountcRecy(uint256 ammount) public view returns (uint256) {
        return ((ammount * TokensPerCelo()) / 10**18);
    }

    function BuyTokens() public payable nonReentrant whenNotPaused {
        uint256 amtCRecy = amountcRecy(msg.value);
        uint256 vendorBalance = _cRecy.balanceOf(address(this));
        if (vendorBalance < amtCRecy) {
            revert InsufficientTokens(vendorBalance, amtCRecy);
        }
        bool sent = _cRecy.transfer(msg.sender, amtCRecy);
        if (sent == false) {
            revert FailBuyTokens(msg.sender, amtCRecy);
        }
        purchaseOrder[msg.sender] += amtCRecy;
        totalSold += amtCRecy;
        emit BuycRecy(msg.sender, msg.value, amtCRecy);
    }

    function getBalancecRecyWContract() public view returns (uint256) {
        uint256 vendorBalance = _cRecy.balanceOf(address(this));
        return vendorBalance;
    }

    function withdraw() public whenNotPaused onlyOwner {
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        if (sent == false) {
            revert FailWithdraw(ownerBalance, msg.sender);
        }
        require(sent, "Failed to send user balance back to the owner");
    }
}
