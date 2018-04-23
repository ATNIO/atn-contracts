pragma solidity ^0.4.13;

import "ds-stop/stop.sol";
import "./TokenTransferGuard.sol";

contract FrozenGuard is DSStop, TokenTransferGuard {

    function FrozenGuard()
    {
    }

    function onTokenTransfer(address _from, address _to, uint _amount) public returns (bool)
    {
        // 2018-04-27 04:00 GMT
        if ( !stopped && block.timestamp >= 1524801600)
        {
            return false;
        }
        
        return true;
    }
}