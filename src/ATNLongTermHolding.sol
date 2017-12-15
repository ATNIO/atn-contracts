pragma solidity ^0.4.13;

import "ds-stop/stop.sol";
import "erc20/erc20.sol";
import "./SafeMath.sol";

contract ATNLongTermHolding is DSStop {
    using SafeMath for uint256;

    uint public constant DEPOSIT_WINDOW                 = 60 days;

    uint public constant WITHDRAWAL_DELAY               = 360 days; // 120 days, 240 days

    uint public constant MAX_AGT_ATN_DEPOSIT_PER_ADDRESS    = 10000000 ether;

    uint public constant RATE       = 115;

    uint public agtAtnReceived      = 0;
    uint public atnSent             = 0;

    uint public depositStartTime    = 0;
    uint public depositStopTime     = 0;

    struct Record {
        uint agtAtnAmount;
        uint timestamp;
    }

    mapping (address => Record) records;

    ERC20 public AGT;
    ERC20 public ATN;

    function ATNLongTermHolding(address _agt, address _atn)
    {
        AGT = ERC20(_agt);
        ATN = ERC20(_atn);
    }

    function start() public auth {
        require(depositStartTime == 0);

        depositStartTime = now;
        depositStopTime  = now + DEPOSIT_WINDOW;

        Started(depositStartTime);
    }

    function tokenFallback(address _from, uint256 _value, bytes _data) public
    {
        tokenFallback(_from, _value);
    }

    // TODO: To test the stoppable can work or not
    function tokenFallback(address _from, uint256 _value) public stoppable
    {
        require(msg.sender == address(AGT) || msg.sender == address(ATN));

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

        Deposit(depositId++, _from, _value);
    }

    function withdrawATN() public stoppable {
        require(msg.sender != owner);
        require(now > depositStopTime);

        var record = records[msg.sender];

        require(now >= record.timestamp + WITHDRAWAL_DELAY);

        uint atnAmount = record.agtAtnAmount.mul(RATE).div(100);

        atnSent += atnAmount;

        require(ATN.transfer(msg.sender, atnAmount));

        delete records[msg.sender];

        Withdrawal(
                   withdrawId++,
                   msg.sender,
                   atnAmount
                   );
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
}
