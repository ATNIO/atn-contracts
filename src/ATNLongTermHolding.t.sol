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
        holding = new ATNLongTermHolding(address(agt), address(atn), address(pool), 115, 0);

        pool.addConsumer(address(holding));

        address[] memory guards = new address[](1);
        guards[0] = address(swap);
        // guards[1] = address(holding);

        agtController = new SwapController(guards);
        agtController.addGuard(address(holding));

        atnController = new SwapController(guards);
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

        atn.mint(address(holding), 10000 ether);

        address[] memory x = new address[](2);
        x[0] = address(user2);
        x[1] = address(user1);

        holding.batchWithdraw(x);

        assertEq(atn.balanceOf(address(holding)) , (20000 - 100 * 115) * (1 ether));

        agtController.changeController(address(agt), this);
        atnController.changeController(address(atn), this);
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

    function testFail_send_to_holding_exceed_reward_limit() {
        pool.changeMaxReward(100 ether);

        TokenUser user1 = new TokenUser(atn);
        TokenUser user2 = new TokenUser(atn);

        atn.mint(user1, 10000 ether);
        atn.mint(user2, 10000 ether);

        holding.start();

        user1.transfer(address(holding), 500 ether);
        assertEq(atn.balanceOf(address(holding)) , 500 ether);

        user2.transfer(address(holding), 500 ether);
        assertEq(atn.balanceOf(address(holding)) , 500 ether);
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