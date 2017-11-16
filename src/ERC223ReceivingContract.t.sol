pragma solidity ^0.4.13;

import "ds-test/test.sol";

import "./ATN.sol";
import "./ERC223ReceivingContract.sol";

contract TokenReceivingEchoDemo {

    ATN atn;

    function TokenReceivingEchoDemo(address _token)
    {
        atn = ATN(_token);
    }

    function tokenFallback(address _from, uint256 _value, bytes _data) public
    {
        // check that the msg.sender _token is equal to token address
        require(msg.sender == address(atn));
        
        atn.transfer(_from, _value);
    }

    function anotherTokenFallback(address _from, uint256 _value) public
    {
        // check that the msg.sender _token is equal to token address
        require(msg.sender == address(atn));
        
        atn.transfer(_from, _value);
    }

    function tokenFallback(address _from, uint256 _value) public
    {
        // check that the msg.sender _token is equal to token address
        require(msg.sender == address(atn));
        
        atn.transfer(_from, _value);
    }
}

contract Nothing {
    // do not have receiveToken API
}

contract ERC223ReceivingContractTest is DSTest, TokenController {
    TokenReceivingEchoDemo echo;
    ATN atn;
    Nothing nothing;

    function proxyPayment(address _owner) payable returns(bool){
        return true;
    }

    function onTransfer(address _from, address _to, uint _amount) returns(bool){
        return true;
    }

    function onApprove(address _owner, address _spender, uint _amount)
        returns(bool)
    {
        return true;
    }

    function setUp() {
        atn = new ATN();
        echo = new TokenReceivingEchoDemo(address(atn));
        nothing = new Nothing();
    }

    function testFail_basic_sanity() {
        assertTrue(false);
    }

    function test_token_fall_back_with_data() {
        atn.mint(this, 10000);
        atn.transfer(address(echo), 5000, "");

        assertTrue(atn.balanceOf(this) == 10000);

        // https://github.com/dapphub/dapp/issues/65
        // need manual testing
        atn.transfer(address(echo), 5000, "", "anotherTokenFallback(address,uint256)");

        assertTrue(atn.balanceOf(this) == 10000);

        atn.transfer(address(nothing), 100);
    }

    function test_token_fall_back_direct() {
        atn.mint(this, 10000);

        assertTrue(atn.balanceOf(this) == 10000);

        atn.transfer(address(echo), 5000);

        assertTrue(atn.balanceOf(this) == 10000);
    }
}

