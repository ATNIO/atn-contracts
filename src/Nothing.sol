pragma solidity ^0.4.13;

import "ds-auth/auth.sol";
import "erc20/erc20.sol";

contract Nothing is DSAuth {
    // do not have receiveToken API
    
    function claimTokens(address _token) public auth {
        if (_token == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20 token = ERC20(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(owner, balance);
        ClaimedTokens(_token, owner, balance);
    }
    
    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
}