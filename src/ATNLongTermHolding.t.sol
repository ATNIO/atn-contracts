pragma solidity ^0.4.13;

import "ds-test/test.sol";

import "./AGT.sol";
import "./ATN.sol";
import "./AGT2ATNSwap.sol";
import "./ATNLongTermHolding.sol";
import "./SwapController.sol";

contract TokenUser {
    ERC20  token;

    function TokenUser(ERC20 token_) {
        token = token_;
    }

    function transfer(address _to, uint256 _value) public returns (bool)
    {
        return token.transfer(_to, _value);
    }
}

contract ATNLongTermHoldingTest is DSTest {
    AGT agt;
    ATN atn;
    AGT2ATNSwap swap;
    ATNLongTermHolding holding;
    SwapController agtController;
    SwapController atnController;

    function setUp() {
        agt = new AGT();
        // agt.changeController(0x0);
        atn = new ATN();
        // atn.changeController(0x0);

        swap = new AGT2ATNSwap(address(agt), address(atn));
        holding = new ATNLongTermHolding(address(agt), address(atn));

        address[] memory guards = new address[](2);
        guards[0] = address(swap);
        guards[1] = address(holding);

        agtController = new SwapController(agt, guards);
        atnController = new SwapController(atn, guards);

        agt.changeController(address(agtController));
        atn.changeController(address(atnController));
    }

    function test_send_to_holding() {
        TokenUser user1 = new TokenUser(atn);
        TokenUser user2 = new TokenUser(atn);

        atn.mint(user1, 10000000 ether);
        atn.mint(user2, 10000000 ether);

        holding.start();

        user1.transfer(address(holding), 5000 ether);

        assertEq(atn.balanceOf(address(holding)) , 5000 ether);

        user2.transfer(address(holding), 5000 ether);

        assertEq(atn.balanceOf(address(holding)) , 10000 ether);
    }

    function testFail_send_to_holding() {
        TokenUser user1 = new TokenUser(atn);

        atn.mint(user1, 10000000 ether);

        holding.start();

        user1.transfer(address(holding), 5000 ether);

        assertEq(atn.balanceOf(address(holding)) , 5000 ether);

        user1.transfer(address(holding), 3000 ether);

        assertEq(atn.balanceOf(address(holding)) , 5000 ether);
    }
}