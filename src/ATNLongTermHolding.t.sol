pragma solidity ^0.4.13;

import "ds-test/test.sol";

import "./AGT.sol";
import "./ATN.sol";
import "./AGT2ATNSwap.sol";
import "./ATNLongTermHolding.sol";
import "./SwapController.sol";
import "./RewardSharedPool.sol";

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
    RewardSharedPool pool;

    function setUp() {
        agt = new AGT();
        // agt.changeController(0x0);
        atn = new ATN();
        // atn.changeController(0x0);

        pool = new RewardSharedPool();

        swap = new AGT2ATNSwap(address(agt), address(atn));
        holding = new ATNLongTermHolding(address(agt), address(atn), address(pool), 115, 360);

        pool.addConsumer(address(holding));

        address[] memory guards = new address[](1);
        guards[0] = address(swap);
        // guards[1] = address(holding);

        agtController = new SwapController(agt, guards);
        agtController.addGuard(address(holding));

        atnController = new SwapController(atn, guards);
        atnController.addGuard(address(holding));

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

    function test_send_to_swap() {
        TokenUser user1 = new TokenUser(agt);

        agt.mint(user1, 10000000 ether);
        atn.mint(address(swap), 10000000 ether);

        assertEq(atn.balanceOf(address(swap)) , 10000000 ether);

        user1.transfer(address(swap), 5000 ether);

        assertEq(atn.balanceOf(address(user1)) , 5000 ether);
        assertEq(atn.balanceOf(address(swap)) , 9995000 ether);
        
        user1.transfer(address(swap), 5000 ether);

        assertEq(atn.balanceOf(address(user1)) , 10000 ether);
        assertEq(atn.balanceOf(address(swap)) , 9990000 ether);
    }

    function testFail_send_to_swap2() {
        TokenUser user1 = new TokenUser(agt);

        agt.mint(user1, 100000 ether);
        atn.mint(address(swap), 10000 ether);

        assertEq(atn.balanceOf(address(swap)) , 10000 ether);

        user1.transfer(address(swap), 5000 ether);

        assertEq(atn.balanceOf(address(user1)) , 5000 ether);
        assertEq(atn.balanceOf(address(swap)) , 5000 ether);
        
        user1.transfer(address(swap), 10000 ether);

        assertEq(atn.balanceOf(address(user1)) , 5000 ether);
        assertEq(atn.balanceOf(address(swap)) , 5000 ether);
    }
}