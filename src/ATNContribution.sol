pragma solidity ^0.4.11;

import "./Owned.sol";
import "./SafeMath.sol";
import "./TokenController.sol";
import "./ATN.sol";
import "./erc20/erc20.sol";

contract ATNContribution is Owned, TokenController {
    using SafeMath for uint256;

    uint256 constant public exchangeRate = 600;   // will be set before the token sale.
    uint256 constant public maxGasPrice = 50000000000;  // 50GWei

    uint256 public maxFirstRoundTokenLimit = 20000000 ether; // ATN have same precision with ETH

    uint256 public maxIssueTokenLimit = 70000000 ether; // ATN have same precision with ETH

    mapping(address => bool) public whiteList;

    ATN public  atn;            // The ATN token itself

    address public atnController;

    address public destEthFoundation;
    address public destTokensAngel;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalNormalTokenGenerated;
    uint256 public totalNormalEtherCollected;

    uint256 public totalIssueTokenGenerated;

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
        paused = false;
    }


    /// @notice This method should be called by the owner before the contribution
    ///  period starts This initializes most of the parameters
    /// @param _atn Address of the ATN token contract
    /// @param _atnController Token controller for the ATN that will be transferred after
    ///  the contribution finalizes.
    /// @param _startTime Time when the contribution period starts
    /// @param _endTime The time that the contribution period ends
    /// @param _destEthFoundation Destination address where the contribution ether is sent
    /// @param _destTokensAngel Address where the tokens for the angels are sent
    function initialize(
        address _atn,
        address _atnController,
        uint _startTime,
        uint _endTime,
        address _destEthFoundation,
        address _destTokensAngel
    ) public onlyOwner {
      // Initialize only once
      require(address(atn) == 0x0);

      atn = ATN(_atn);
      require(atn.totalSupply() == 0);
      require(atn.controller() == address(this));
      require(atn.decimals() == 18);  // Same amount of decimals as ETH

      startTime = _startTime;
      endTime = _endTime;

      assert(startTime < endTime);

      require(_atnController != 0x0);
      atnController = _atnController;

      require(_destEthFoundation != 0x0);
      destEthFoundation = _destEthFoundation;

      require(_destTokensAngel != 0x0);
      destTokensAngel = _destTokensAngel;
  }

    function saveWhiteList(address _addr, bool alive) public onlyOwner {
        whiteList[_addr] = alive;
        // EventSaveSwap(true);
    }

  /// @notice If anybody sends Ether directly to this contract, consider he is
  ///  getting ATNs.
  function () public payable notPaused {
      proxyPayment(msg.sender);
  }


  //////////
  // MiniMe Controller functions
  //////////

  /// @notice This method will generally be called by the ATN token contract to
  ///  acquire ATNs. Or directly from third parties that want to acquire ATNs in
  ///  behalf of a token holder.
  /// @param _th ATN holder where the ATNs will be minted.
  function proxyPayment(address _th) public payable notPaused initialized contributionOpen returns (bool) {
      require(_th != 0x0);
      require(whiteList[_th]);

      buyNormal(_th);

      return true;
  }

  function onTransfer(address, address, uint256) public returns (bool) {
      return false;
  }

  function onApprove(address, address, uint256) public returns (bool) {
      return false;
  }

  function buyNormal(address _th) internal {
      require(tx.gasprice <= maxGasPrice);

      // Antispam mechanism
      // TODO: Is this checking useful?
      address caller;
      if (msg.sender == address(atn)) {
          caller = _th;
      } else {
          caller = msg.sender;
      }

      // Do not allow contracts to game the system
      require(!isContract(caller));

      doBuy(_th, msg.value);
  }

  function doBuy(address _th, uint256 _toFund) internal {
      require(tx.gasprice <= maxGasPrice);

      assert(msg.value >= _toFund);  // Not needed, but double check.
      assert(totalNormalTokenGenerated < maxFirstRoundTokenLimit);

      uint256 endOfFirstWeek = startTime.add(1 weeks);
      uint256 endOfSecondWeek = startTime.add(2 weeks);
      uint256 finalExchangeRate = exchangeRate;
      if (now < endOfFirstWeek)
      {
          // 10% Bonus in first week
          finalExchangeRate = exchangeRate.mul(110).div(100);
      } else if (now < endOfSecondWeek)
      {
          // 5% Bonus in second week
          finalExchangeRate = exchangeRate.mul(105).div(100);
      }

      if (_toFund > 0) {
          uint256 tokensGenerating = _toFund.mul(finalExchangeRate);

          uint256 tokensToBeGenerated = totalNormalTokenGenerated.add(tokensGenerating);
          if (tokensToBeGenerated > maxFirstRoundTokenLimit)
          {
              tokensGenerating = maxFirstRoundTokenLimit - totalNormalTokenGenerated;
              _toFund = tokensGenerating.div(finalExchangeRate);
          }

          atn.mint(_th, tokensGenerating);
          destEthFoundation.transfer(_toFund);

          totalNormalTokenGenerated = totalNormalTokenGenerated.add(tokensGenerating);

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

  function issueTokenToGuaranteedAddress(address _th, uint256 _amount, bytes data) onlyOwner initialized notPaused contributionOpen {
      require(totalIssueTokenGenerated.add(_amount) <= maxIssueTokenLimit);

      atn.mint(_th, _amount);

      totalIssueTokenGenerated = totalIssueTokenGenerated.add(_amount);

      NewIssue(_th, _amount, data);
  }

  function adjustLimitBetweenIssueAndNormal(uint256 _amount, bool _isAddToNormal) onlyOwner initialized contributionOpen {
      if(_isAddToNormal)
      {
          require(totalIssueTokenGenerated.add(_amount) <= maxIssueTokenLimit);
          maxIssueTokenLimit = maxIssueTokenLimit.sub(_amount);
          maxFirstRoundTokenLimit = maxFirstRoundTokenLimit.add(_amount);
      } else {
          require(totalNormalTokenGenerated.add(_amount) <= maxFirstRoundTokenLimit);
          maxFirstRoundTokenLimit = maxFirstRoundTokenLimit.sub(_amount);
          maxIssueTokenLimit = maxIssueTokenLimit.add(_amount);
      }
  }

  // NOTE on Percentage format
  // Right now, Solidity does not support decimal numbers. (This will change very soon)
  //  So in this contract we use a representation of a percentage that consist in
  //  expressing the percentage in "x per 10**18"
  // This format has a precision of 16 digits for a percent.
  // Examples:
  //  3%   =   3*(10**16)
  //  100% = 100*(10**16) = 10**18
  //
  // To get a percentage of a value we do it by first multiplying it by the percentage in  (x per 10^18)
  //  and then divide it by 10**18
  //
  //              Y * X(in x per 10**18)
  //  X% of Y = -------------------------
  //               100(in x per 10**18)
  //


  /// @notice This method will can be called by the owner before the contribution period
  ///  end or by anybody after the `endBlock`. This method finalizes the contribution period
  ///  by creating the remaining tokens and transferring the controller to the configured
  ///  controller.
  function finalize() public onlyOwner initialized {
      require(time() >= startTime);
      // require(msg.sender == owner || time() > endTime);
      require(finalizedBlock == 0);

      finalizedBlock = getBlockNumber();
      finalizedTime = now;

      uint256 tokensToSecondRound = 90000000 ether;

      uint256 tokensToReserve = 90000000 ether;

      uint256 tokensToAngelAndOther = 30000000 ether;

      // totalTokenGenerated should equal to ATN.totalSupply()

      // If tokens in first round is not sold out, they will be added to second round and frozen together
      tokensToSecondRound = tokensToSecondRound.add(maxFirstRoundTokenLimit).sub(totalNormalTokenGenerated);

      tokensToSecondRound = tokensToSecondRound.add(maxIssueTokenLimit).sub(totalIssueTokenGenerated);

      uint256 totalTokens = 300000000 ether;

      require(totalTokens == atn.totalSupply().add(tokensToSecondRound).add(tokensToReserve).add(tokensToAngelAndOther));

      atn.mint(0xb1, tokensToSecondRound);

      atn.mint(0xb2, tokensToReserve);

      atn.mint(destTokensAngel, tokensToAngelAndOther);

      // totalTokens should equal to ATN.totalSupply()

      atn.changeController(atnController);

      Finalized();
  }

  function percent(uint256 p) internal returns (uint256) {
      return p.mul(10**16);
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
      if (atn.controller() == address(this)) {
          atn.claimTokens(_token);
      }
      if (_token == 0x0) {
          owner.transfer(this.balance);
          return;
      }

      ERC20 token = ERC20(_token);
      uint256 balance = token.balanceOf(this);
      token.transfer(owner, balance);
      ClaimedTokens(_token, owner, balance);
  }

  /// @notice Pauses the contribution if there is any issue
  function pauseContribution() onlyOwner {
      paused = true;
  }

  /// @notice Resumes the contribution
  function resumeContribution() onlyOwner {
      paused = false;
  }

  event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
  event NewSale(address indexed _th, uint256 _amount, uint256 _tokens);
  event NewIssue(address indexed _th, uint256 _amount, bytes data);
  event Finalized();
}
