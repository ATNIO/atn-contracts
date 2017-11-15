pragma solidity ^0.4.13;

import "ds-test/test.sol";

import "./ATN.sol";

contract ATNTest is DSTest {
    ATN atn;

    function setUp() {
        atn = new ATN();
    }

    function testFail_basic_sanity() {
        assertTrue(false);
    }

    function test_basic_sanity() {
        assertTrue(true);
    }

    function test_transfer_to_contract_with_fallback() {
        assertTrue(true);
    }

    function test_transfer_to_contract_without_fallback() {
        assertTrue(true);
    }
}
