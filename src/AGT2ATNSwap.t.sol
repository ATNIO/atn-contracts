pragma solidity ^0.4.13;

import "ds-test/test.sol";

import "./AGT.sol";
import "./ATN.sol";
import "./AGT2ATNSwap.sol";

contract AGT2ATNSwapTest is DSTest {
    AGT agt;
    ATN atn;
    AGT2ATNSwap swap;

    function setUp() {
        agt = new AGT();
        agt.changeController(0x0);
        atn = new ATN();
        atn.changeController(0x0);

        swap = new AGT2ATNSwap(address(agt), address(atn));
    }

    function test_swap() {
        agt.mint(this, 10000);
        atn.mint(address(swap), 10000);

         assertEq(atn.balanceOf(address(swap)) , 10000);


        agt.transfer(address(swap), 5000);

        assertEq(atn.balanceOf(this) , 5000);
        assertEq(agt.balanceOf(address(swap)) , 5000);

        agt.transfer(address(swap), 5000, "");

        assertEq(atn.balanceOf(this) , 10000);
        assertEq(agt.balanceOf(address(swap)) , 10000);
    }
}