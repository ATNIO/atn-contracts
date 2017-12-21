pragma solidity ^0.4.13;

import "ds-stop/stop.sol";
import "erc20/erc20.sol";
import "./SafeMath.sol";
import "./TokenTransferGuard.sol";
import "./RewardSharedPool.sol";

contract ATNLongTermHolding is DSStop, TokenTransferGuard {
    using SafeMath for uint256;

    uint public constant DEPOSIT_WINDOW                 = 60 days;

    // There are three kinds of options: 1. {105, 120 days}, 2. {110, 240 days}, 3. {115, 360 days}
    uint public rate = 105;
    uint public withdrawal_delay    = 120 days;

    uint public agtAtnReceived      = 0;
    uint public atnSent             = 0;

    uint public depositStartTime    = 0;
    uint public depositStopTime     = 0;

    RewardSharedPool public pool;

    struct Record {
        uint agtAtnAmount;
        uint timestamp;
    }

    mapping (address => Record) public records;

    ERC20 public AGT;
    ERC20 public ATN;

    uint public gasRequired;

    function ATNLongTermHolding(address _agt, address _atn, address _poolAddress, uint _rate, uint _delayDays)
    {
        AGT = ERC20(_agt);
        ATN = ERC20(_atn);

        pool = RewardSharedPool(_poolAddress);

        require(_rate > 100);

        rate = _rate;
        withdrawal_delay = _delayDays * 1 days;
    }

    function start() public auth {
        require(depositStartTime == 0);

        depositStartTime = now;
        depositStopTime  = now + DEPOSIT_WINDOW;

        Started(depositStartTime);
    }

    function changeDepositStopTimeFromNow(uint _daysFromNow) public auth {
        depositStopTime = now + _daysFromNow * 1 days;
    }

    function tokenFallback(address _from, uint256 _value, bytes _data) public
    {
        tokenFallback(_from, _value);
    }

    // TODO: To test the stoppable can work or not
    function tokenFallback(address _from, uint256 _value) public stoppable
    {
        if (msg.sender == address(AGT) || msg.sender == address(ATN))
        {
            // the owner is not count in the statistics
            // Only owner can use to deposit the ATN reward things.
            if (_from == owner)
            {
                return;
            }

            require(now <= depositStopTime);

            var record = records[_from];

            record.agtAtnAmount += _value;
            record.timestamp = now;
            records[_from] = record;

            agtAtnReceived += _value;

            pool.consume( _value.mul(rate - 100 ).div(100) );

            Deposit(depositId++, _from, _value);
        }
    }

    function onTokenTransfer(address _from, address _to, uint _amount) public returns (bool)
    {
        if (_to == address(this) && _from != owner)
        {
            if (msg.gas < gasRequired) return false;
            
            if (stopped) return false;
            if (now > depositStopTime) return false;

            // each address can only deposit once.
            var record = records[_from];
            if (record.timestamp > 0 ) return false;

            // can not over the limit of maximum reward amount
            if ( !pool.available( _amount.mul(rate - 100 ).div(100) ) ) return false;
        }

        return true;
    }

    function withdrawATN() public stoppable {
        require(msg.sender != owner);

        var record = records[msg.sender];

        require(record.timestamp > 0);

        require(now >= record.timestamp + withdrawal_delay);

        withdrawForAddress(msg.sender);
    }

    function withdrawForAddress(address _addr) internal {
        var record = records[_addr];
        
        uint atnAmount = record.agtAtnAmount.mul(rate).div(100);

        require(ATN.transfer(_addr, atnAmount));

        atnSent += atnAmount;

        delete records[_addr];

        Withdrawal(
                   withdrawId++,
                   _addr,
                   atnAmount
                   );
    }

    function batchWithdraw(address[] _addrList) public stoppable {
        for (uint i = 0; i < _addrList.length; i++) {
            var record = records[_addrList[i]];
            if (record.timestamp > 0 && now >= record.timestamp + withdrawal_delay)
            {
                withdrawForAddress(_addrList[i]);
            }
        }
    }

    function changeGasRequired(uint _gasRequired) public auth {
        gasRequired = _gasRequired;
        ChangeGasRequired(_gasRequired);
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

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);

    /*
     * EVENTS
     */
    /// Emitted when program starts.
    event Started(uint _time);

    /// Emitted for each sucuessful deposit.
    uint public depositId = 0;
    event Deposit(uint _depositId, address indexed _addr, uint agtAtnAmount);

    /// Emitted for each sucuessful withdrawal.
    uint public withdrawId = 0;
    event Withdrawal(uint _withdrawId, address indexed _addr, uint _atnAmount);

    event ChangeGasRequired(uint _gasRequired);
}
