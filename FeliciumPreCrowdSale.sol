pragma solidity >=0.6.1;

import "./token/FeliciumToken.sol";
import "./libs/SafeMath.sol";
import "./abstract/Ownable.sol";
import "./FeliciumRefundVault.sol";
import "./libs/SafeERC20.sol";

contract FeliciumPreCrowdSale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for FeliciumToken;

    // The token being sold
    FeliciumToken public token;

    // Address where funds are collected
    address payable public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate;

    // Amount of wei raised
    uint256 public weiRaised;

    // Minimal amount of wei to invest
    uint256 public minWei;

    // Minimal amount of wei to be raised
    uint256 public minCap;

    // Maximum amount of wei to be raised
    uint256 public maxCap;

    // refund vault used to hold funds while crowdsale is running
    FeliciumRefundVault public vault;

    uint256 public closingTime;

    bool public isFinalized = false;

    mapping(address => bool) public whitelist;


    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event Finalized();

    /**
    * @dev Reverts if not in crowdsale time range.
    */
    modifier onlyWhileOpen {
        require(block.timestamp <= closingTime, "Crowdsale is not open!");
        _;
    }

    /**
    * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
    */
    modifier isWhitelisted(address _beneficiary) {
        require(whitelist[_beneficiary], "Non-whitelisted beneficiary");
        _;
    }


    /**
    * @param _rate Number of token units a buyer gets per wei
    * @param _wallet Address where collected funds will be forwarded to
    * @param _token Address of the token being sold
    * @param _minWei Minimal amount of wei to invest 
    * @param _minCap Minimal amount of wei to be raised
    * @param _maxCap Maximum amount of wei to be raised
    */
    constructor(uint256 _rate, address payable _wallet, FeliciumToken _token, uint256 _minWei, uint256 _minCap, uint256 _maxCap) public {
        require(_rate > 0, "Rate is lower or equal to 0");
        require(_wallet != address(0), "Address is zero account");
        require(address(_token) != address(0), "Address is zero account");
        require(_minCap > 0, "Min cap is lower or equal to 0");
        require(_maxCap > 0, "Max cap is lower or equal to 0");

        rate = _rate;
        wallet = _wallet;
        token = _token;
        minWei = _minWei;
        minCap = _minCap;
        maxCap = _maxCap;
        vault = new FeliciumRefundVault(wallet);
        closingTime = block.timestamp + 97 days;
    }

    /**
    * @dev fallback function ***DO NOT OVERRIDE***
    */
    fallback () external payable {
        buyTokens(msg.sender);
    }

    receive () external payable {
        buyTokens(msg.sender);
    }

    /**
    * @dev low level token purchase ***DO NOT OVERRIDE***
    * @param _beneficiary Address performing the token purchase
    */
    function buyTokens(address payable _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        uint256 weiRefundAmount = 0;

        // Check if we've reached the maxCap
        if (weiRaised.add(weiAmount) > maxCap) {
            weiRefundAmount = weiRaised.add(weiAmount) - maxCap;
            weiAmount = weiAmount.sub(weiRefundAmount);
        }
        
        if (weiRefundAmount > 0) {
            _preValidatePurchaseOvershoot(_beneficiary, weiAmount);
        } else {
            _preValidatePurchase(_beneficiary, weiAmount);
        }
        

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(
            msg.sender,
            _beneficiary,
            weiAmount,
            tokens
        );

        // Refund the user
        if (weiRefundAmount > 0) {
            _beneficiary.transfer(weiRefundAmount);
        }

        _forwardFunds(weiAmount);
        
    }

    /**
    * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
    * @param _beneficiary Address performing the token purchase
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal view onlyWhileOpen isWhitelisted(_beneficiary) {
        require(_beneficiary != address(0));
        require(_weiAmount >= minWei);
        require(weiRaised.add(_weiAmount) <= maxCap);
    }

    function _preValidatePurchaseOvershoot(address _beneficiary, uint256 _weiAmount) internal view onlyWhileOpen isWhitelisted(_beneficiary) {
        require(_beneficiary != address(0));
        require(weiRaised.add(_weiAmount) <= maxCap);
    }

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _tokenAmount Number of tokens to be emitted
    */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.safeTransfer(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
    * @param _beneficiary Address receiving the tokens
    * @param _tokenAmount Number of tokens to be purchased
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Override to extend the way in which ether is converted to tokens.
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(rate);
    }

    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    * IGNORE {value: ...}-warning; this will break verify
    */
    function _forwardFunds(uint256 weiAmount) internal {
        vault.deposit.value(weiAmount)(msg.sender);
    }

    function hasReachedMinCap() public view returns (bool) {
        return weiRaised >= minCap;
    }

    function hasReachedMaxCap() public view returns (bool) {
        return weiRaised >= maxCap;
    }

    /**
    * @dev Checks whether the period in which the crowdsale is open has already elapsed.
    * @return Whether crowdsale period has elapsed
    */
    function hasClosed() public view returns (bool) {
        return block.timestamp > closingTime;
    }

    function goalReached() public view returns (bool) {
        return ((hasReachedMinCap() && hasClosed()) || hasReachedMaxCap());
    }

    function finalizeCrowdsale() onlyOwner public {
        require(!isFinalized);
        require(hasClosed() || hasReachedMaxCap());

        if (goalReached()) {
            vault.close();

            // Transfer remaining FEL back to the token
            address crowdsale = address(this);
            uint256 crowdsaleFeliciumBalance = token.balanceOf(crowdsale);
            if (crowdsaleFeliciumBalance > 0) {
                token.transfer(owner(), crowdsaleFeliciumBalance);
            }

        } else {
            vault.enableRefunds();
        }

        emit Finalized();
        isFinalized = true;    
    }

    /**
    * @dev Investors can claim refunds here if crowdsale is unsuccessful
    * POTENTIALLY OBSOLETE, USE VAULT DIRECTLY
    */
    function claimRefund() external {
        require(isFinalized);
        require(!goalReached());

        vault.refund(msg.sender);
    }

    function updateContract(uint256 _rate, uint256 _minCap, uint256 _maxCap, uint256 _minWei, uint256 _closingTime) onlyOwner external {
        rate = _rate;
        minCap = _minCap;
        maxCap = _maxCap;
        minWei = _minWei;
        closingTime = _closingTime;
    }

    /**
    * @dev Adds single address to whitelist.
    * @param _beneficiary Address to be added to the whitelist
    */
    function addToWhitelist(address _beneficiary) external onlyOwner {
        whitelist[_beneficiary] = true;
    }

    /**
    * @dev Adds list of addresses to whitelist. Not overloaded due to limitations with truffle testing.
    * @param _beneficiaries Addresses to be added to the whitelist
    */
    function addManyToWhitelist(address[] calldata _beneficiaries) external onlyOwner {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            whitelist[_beneficiaries[i]] = true;
        }
    }

    /**
    * @dev Removes single address from whitelist.
    * @param _beneficiary Address to be removed to the whitelist
    */
    function removeFromWhitelist(address _beneficiary) external onlyOwner {
        whitelist[_beneficiary] = false;
    }
}