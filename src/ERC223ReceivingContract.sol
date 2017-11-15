pragma solidity ^0.4.13;

 /*
 * Contract that is working with ERC223 tokens
 * https://github.com/ethereum/EIPs/issues/223
 */

/// @title ERC223ReceivingContract - Standard contract implementation for compatibility with ERC223 tokens.
contract ERC223ReceivingContract {

    /// @dev Function that is called when a user or another contract wants to transfer funds.
    /// @param _from Transaction initiator, analogue of msg.sender
    /// @param _value Number of tokens to transfer.
    /// @param _data Data containig a function signature and/or parameters
    function tokenFallback(address _from, uint256 _value, bytes _data) public;


    /// @dev For ERC20 backward compatibility, same with above tokenFallback but without data.
    /// The function execution could fail, but do not influence the token transfer.
    /// @param _from Transaction initiator, analogue of msg.sender
    /// @param _value Number of tokens to transfer.
    //  function tokenFallback(address _from, uint256 _value) public;
}
