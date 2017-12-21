pragma solidity ^0.4.13;

import "ds-stop/stop.sol";
import "erc20/erc20.sol";
import "./TokenTransferGuard.sol";

contract AGT2ATNSwap is DSStop, TokenTransferGuard {
    ERC20 public AGT;
    ERC20 public ATN;

    uint public gasLimit;

    function AGT2ATNSwap(address _agt, address _atn)
    {
        AGT = ERC20(_agt);
        ATN = ERC20(_atn);
    }

    function tokenFallback(address _from, uint256 _value, bytes _data) public
    {
        tokenFallback(_from, _value);
    }

    function tokenFallback(address _from, uint256 _value) public
    {
        if(msg.sender == address(AGT))
        {
            require(ATN.transfer(_from, _value));

            TokenSwap(_from, _value);
        }
    }

    function onTokenTransfer(address _from, address _to, uint _amount) public returns (bool)
    {
        if (_to == address(this))
        {
            if (msg.gas < gasLimit) return false;

            if (stopped) return false;

            if (ATN.balanceOf(this) < _amount) return false;
        }

        return true;
    }

    function changeGasLimit(uint _gasLimit) public auth {
        gasLimit = _gasLimit;
        ChangeGasLimit(_gasLimit);
    }

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
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

    event TokenSwap(address indexed _from, uint256 _value);
    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);

    event ChangeGasLimit(uint _gasLimit);
}
