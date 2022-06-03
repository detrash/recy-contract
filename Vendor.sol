// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./erc20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vendor is Ownable,ReentrancyGuard,Pausable{

//EVENTOS

//CONTRATO DO TOKEN

    MyToken cRecy;

// PRICE PERBACTH
    uint256  public PricecRecy;

//TOTAL SOLD
    uint256 public totalSold;

//Total MWP per address

    mapping(address => uint) public purchaseOrder;

//ROLES
    event Pause();
    event unPause();
    event BuycRecy(address account, uint Celo, uint _cRecy);
    
    error FailWithdraw(uint ownerBalance, address sender);
    error FailBuyTokens(address account,uint256 value);
    error InsufficientTokens(uint  vendorBalance, uint cRecy);


//Constructor, cria interface token, seta roles
    constructor(address mwpAddress){
    cRecy = MyToken(mwpAddress);
    setPricecRecy(7*10**17);
    }

    function pause() public onlyOwner {
        _pause();
        emit Pause();
    }

    function unpause() public onlyOwner {
        _unpause();
        emit unPause();
    }

    function setPricecRecy(uint _price) public onlyOwner {
        PricecRecy=_price;
    }

    function TokensperCelo() public view returns (uint){
        return 10**36/PricecRecy;
    }

    function amountcRecy(uint ammount) public view returns(uint){
        return (ammount*TokensperCelo()/10**18);
    }

    function BuyTokens() public payable nonReentrant whenNotPaused {
        uint _cRecy = amountcRecy(msg.value);
        uint256 vendorBalance = cRecy.balanceOf(address(this));
        if(vendorBalance < _cRecy){
            revert InsufficientTokens(vendorBalance, _cRecy);
        }
        (bool sent) = cRecy.transfer(msg.sender, _cRecy);
        if(sent == false){
            revert FailBuyTokens(msg.sender, _cRecy);
        }
        purchaseOrder[msg.sender]+=_cRecy;
        totalSold+=_cRecy;
        emit BuycRecy(msg.sender, msg.value, _cRecy);
    }



    function getBalancecRecyWContract() public view returns(uint256){
        uint256 vendorBalance = cRecy.balanceOf(address(this));
        return vendorBalance;
    }


    function withdraw() public whenNotPaused onlyOwner {
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        if(sent == false){
            revert FailWithdraw(ownerBalance, msg.sender);
        }
        require(sent, "Failed to send user balance back to the owner");
  }


}