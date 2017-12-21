pragma solidity ^0.4.13;

import "ds-stop/stop.sol";
import "./SafeMath.sol";

contract RewardSharedPool is DSStop {
    using SafeMath for uint256;

    uint public maxReward      = 1000000 ether;

    uint public consumed   = 0;

    mapping(address => bool) public consumers;

    modifier onlyConsumer {
        require(msg.sender == owner || consumers[msg.sender]);
        _;
    }

    function RewardSharedPool()
    {
    }

    function consume(uint amount) onlyConsumer public returns (bool)
    {
        require(available(amount));

        consumed = consumed.add(amount);

        Consume(msg.sender, amount);

        return true;
    }

    function available(uint amount) constant public returns (bool)
    {
        return consumed.add(amount) <= maxReward;
    }

    function changeMaxReward(uint _maxReward) auth public
    {
        maxReward = _maxReward;
    }

    function addConsumer(address consumer) public auth
    {
        consumers[consumer] = true;

        ConsumerAddition(consumer);
    }

    function removeConsumer(address consumer) public auth
    {
        consumers[consumer] = false;

        ConsumerRemoval(consumer);
    }

    event Consume(address indexed _sender, uint _value);
    event ConsumerAddition(address indexed _consumer);
    event ConsumerRemoval(address indexed _consumer);
}