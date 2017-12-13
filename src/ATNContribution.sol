pragma solidity ^0.4.11;

import "Owned.sol";
import "SafeMath.sol";
import "./ATN.sol";
import "erc20/erc20.sol";

contract ATNContribution is Owned {
    using SafeMath for uint256;

    uint256 constant public exchangeRate = 400;   // will be set before the token sale.
    uint256 constant public maxGasPrice = 100000000000;  // 100GWei

    mapping(address => bool) public whiteList;

    ATN public  atn;            // The ATN token itself

    address public destEthFoundation;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalNormalTokenTransfered;
    uint256 public totalNormalEtherCollected;

    uint256 public finalizedBlock;
    uint256 public finalizedTime;

     bool public paused;

    modifier initialized() {
        require(address(atn) != 0x0);
        _;
    }

    modifier contributionOpen() {
        require(time() >= startTime &&
              time() <= endTime &&
              finalizedBlock == 0 &&
              address(atn) != 0x0);
        _;
    }

     modifier notPaused() {
         require(!paused);
         _;
     }

    function ATNContribution() {
    }


    /// @notice This method should be called by the owner before the contribution
    ///  period starts This initializes most of the parameters
    /// @param _atn Address of the ATN token contract
    ///  the contribution finalizes.
    /// @param _startTime Time when the contribution period starts
    /// @param _endTime The time that the contribution period ends
    /// @param _destEthFoundation Destination address where the contribution ether is sent
    function initialize(
        address _atn,
        uint _startTime,
        uint _endTime,
        address _destEthFoundation
    ) public onlyOwner {
      // Initialize only once
      require(address(atn) == 0x0);

      atn = ATN(_atn);
      require(atn.decimals() == 18);  // Same amount of decimals as ETH

      startTime = _startTime;
      endTime = _endTime;

      assert(startTime < endTime);

      require(_destEthFoundation != 0x0);
      destEthFoundation = _destEthFoundation;

    }

    function saveWhiteList(address[] _addrList, bool alive) public onlyOwner {
        for (uint i = 0; i < _addrList.length; i++) {
            whiteList[_addrList[i]] = alive;
        }
        // EventSaveSwap(true);
    }

    function savePaused(bool _paused) public onlyOwner {
            paused = _paused;
    }

  /// @notice If anybody sends Ether directly to this contract, consider he is
  ///  getting ATNs.
  function () public payable {
      proxyPayment(msg.sender);

  }

  /// @notice This method will generally be called by the ATN token contract to
  ///  acquire ATNs. Or directly from third parties that want to acquire ATNs in
  ///  behalf of a token holder.
  /// @param _th ATN holder where the ATNs will be minted.
  function proxyPayment(address _th) public payable initialized contributionOpen notPaused returns (bool) {
      require(_th != 0x0);
      require(whiteList[_th]);

      buyNormal(_th);

      return true;
  }

  function buyNormal(address _th) internal {
      require(tx.gasprice <= maxGasPrice);

    //   // Antispam mechanism
    //   // TODO: Is this checking useful?
      address caller;
      if (msg.sender == address(atn)) {
          caller = _th;
      } else {
          caller = msg.sender;
      }

    //   // Do not allow contracts to game the system
      require(!isContract(caller));

      doBuy(_th, msg.value);
  }

  function doBuy(address _th, uint256 _toFund) public {
      require(tx.gasprice <= maxGasPrice);

      assert(msg.value >= _toFund);  // Not needed, but double check.

      uint256 endOfFirstWeek = startTime.add(1 weeks);
      uint256 endOfSecondWeek = startTime.add(2 weeks);
      uint256 finalExchangeRate = exchangeRate;
      if (now < endOfFirstWeek) {
          // 10% Bonus in first week
          finalExchangeRate = exchangeRate.mul(110).div(100);
      } else if (now < endOfSecondWeek) {
          // 5% Bonus in second week
          finalExchangeRate = exchangeRate.mul(105).div(100);
      }

      if (_toFund > 0) {
          uint256 tokensGenerating = _toFund.mul(finalExchangeRate);

          require(tokensGenerating <= atn.balanceOf(this));

          require(atn.transfer(_th, tokensGenerating));

          destEthFoundation.transfer(_toFund);

          totalNormalTokenTransfered = totalNormalTokenTransfered.add(tokensGenerating);

          totalNormalEtherCollected = totalNormalEtherCollected.add(_toFund);

          NewSale(_th, _toFund, tokensGenerating);
      }

      uint256 toReturn = msg.value.sub(_toFund);
      if (toReturn > 0) {
          // TODO: If the call comes from the Token controller,
          // then we return it to the token Holder.
          // Otherwise we return to the sender.
          if (msg.sender == address(atn)) {
              _th.transfer(toReturn);
          } else {
              msg.sender.transfer(toReturn);
          }
      }
  }


  /// @dev Internal function to determine if an address is a contract
  /// @param _addr The address being queried
  /// @return True if `_addr` is a contract
  function isContract(address _addr) constant internal returns (bool) {
      if (_addr == 0) return false;
      uint256 size;
      assembly {
          size := extcodesize(_addr)
      }
      return (size > 0);
  }

  function time() constant returns (uint) {
      return block.timestamp;
  }

  //////////
  // Constant functions
  //////////

  /// @return Total tokens issued in weis.
  function tokensIssued() public constant returns (uint256) {
      return atn.totalSupply();
  }

  //////////
  // Testing specific methods
  //////////

  /// @notice This function is overridden by the test Mocks.
  function getBlockNumber() internal constant returns (uint256) {
      return block.number;
  }

  //////////
  // Safety Methods
  //////////

  /// @notice This method can be used by the controller to extract mistakenly
  ///  sent tokens to this contract.
  /// @param _token The address of the token contract that you want to recover
  ///  set to 0 in case you want to extract ether.
  function claimTokens(address _token) public onlyOwner {
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
  event NewSale(address indexed _th, uint256 _amount, uint256 _tokens);
  event NewIssue(address indexed _th, uint256 _amount, bytes data);
  event Finalized();
}
