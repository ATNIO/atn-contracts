pragma solidity ^0.4.13;

contract ERC223 {
    function transfer(address to, uint value, bytes data) returns (bool ok);

    function transfer(address to, uint value, bytes data, string custom_fallback) returns (bool ok);

    event ERC223Transfer(address indexed from, address indexed to, uint value, bytes data);
}
