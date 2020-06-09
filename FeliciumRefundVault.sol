pragma solidity >=0.6.1;

import "./libs/SafeMath.sol";
import "./abstract/Ownable.sol";

contract FeliciumRefundVault is Ownable {
    using SafeMath for uint256;

    enum State { Active, Refunding, Closed }

    mapping (address => uint256) public deposited;
    address payable public wallet;
    State public state;

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);

    /**
    * @param _wallet Vault address
    */
    constructor(address payable _wallet) public {
        require(_wallet != address(0), "Invalid address");
        wallet = _wallet;
        state = State.Active;
    }

    /**
    * @param investor Investor address
    */
    function deposit(address investor) public onlyOwner payable {
        require(state == State.Active, "State not active");
        deposited[investor] = deposited[investor].add(msg.value);
    }

    function close() public onlyOwner {
        require(state == State.Active, "State not active");
        state = State.Closed;
        emit Closed();
        wallet.transfer(address(this).balance);
    }

    function enableRefunds() public onlyOwner {
        require(state == State.Active, "State not active");
        state = State.Refunding;
        emit RefundsEnabled();
    }

    /**
    * @param investor Investor address
    */
    function refund(address payable investor) public {
        require(state == State.Refunding, "State not refunding");
        uint256 depositedValue = deposited[investor];
        deposited[investor] = 0;
        investor.transfer(depositedValue);
        emit Refunded(investor, depositedValue);
    }

}