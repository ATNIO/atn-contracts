pragma solidity ^0.4.13;

import "ds-auth/auth.sol";
import "erc20/erc20.sol";
import "./TokenController.sol";
import "./Controlled.sol";
import "./TokenTransferGuard.sol";

contract SwapController is DSAuth, TokenController {
    Controlled public controlled;

    TokenTransferGuard[] guards;

    function SwapController(address _token, address[] _guards)
    {
        controlled = Controlled(_token);

        for (uint i=0; i<_guards.length; i++) {
            addGuard(_guards[i]);
        }
    }

    function changeController(address _newController) public auth {
        controlled.changeController(_newController);
    }

    function proxyPayment(address _owner) payable public returns (bool)
    {
        return false;
    }

    function onTransfer(address _from, address _to, uint _amount) public returns (bool)
    {
        for (uint i=0; i<guards.length; i++)
        {
            if (!guards[i].onTokenTransfer(_from, _to, _amount))
            {
                return false;
            }
        }

        return true;
    }

    function onApprove(address _owner, address _spender, uint _amount) public returns (bool)
    {
        return true;
    }

    function addGuard(address _guard) public auth
    {
        guards.push(TokenTransferGuard(_guard));
    }
}