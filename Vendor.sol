// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./erc20.sol";

contract Vendor {

//EVENTOS

//CONTRATO DO TOKEN

    MyToken cRecy;

// PRICE PERBACTH
    uint256  public PricecRecy;


//TOTAL SOLD
    uint256 public totalSold;


//TOTAL SOLD PER BACTH

    bool public isPause;

//Total MWP per address
    mapping (address => uint256) public totalTokens;

//ROLES
    event FailWithdraw(uint ownerBalance, address sender);
    event FailBuyTokens(address account,uint256 value);
    event InsufficientTokens(uint indexed vendorBalance, uint indexed totalTokens);
//Constructor, cria interface token, seta roles
    constructor(address mwpAddress){
    cRecy = MyToken(mwpAddress);
    setPricecRecy(7*10**17);
    }

    function setPricecRecy(uint _price)public{
        PricecRecy=_price;
    }

    function setIsPause() public{
        isPause = true;
    }

    modifier notPause(){
        require(isPause == false, "Contract is Pause");
        _;
    }

    function TokensperCelo() public view returns (uint){
        return 10**36/PricecRecy;
    }

    function Tokens(uint ammount) public view returns(uint){
        return (ammount*TokensperCelo()/10**18);
    }

    function BuyTokens() public payable{
        uint _tokens = Tokens(msg.value);
        uint256 vendorBalance = cRecy.balanceOf(address(this));

        (bool sent) = cRecy.transfer(msg.sender, _tokens);
        //Caso falhe lançar um evento
        if(sent == false){
            emit FailBuyTokens(msg.sender,_tokens);
        }
        require(sent, "Failed to transfer token to user");
    }



    function getBalancecRecyWContract() public view returns(uint256){
        uint256 vendorBalance = cRecy.balanceOf(address(this));
        return vendorBalance;
    }


    function withdraw() public notPause{
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        if(sent == false){
            emit FailWithdraw(ownerBalance, msg.sender);
        }
        require(sent, "Failed to send user balance back to the owner");
  }


}