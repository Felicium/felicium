pragma solidity >=0.6.1;

import "./Context.sol";
import "./Ownable.sol";
/**
 * @title TokenOwnable
 * @dev The TokenOwnable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract TokenOwnable is Ownable {
    address private _tokenAddress;

  /**
   * @dev The TokenOwnable constructor sets the original `owner` of the contract to the sender
   * account.
   */
    constructor(address tokenAddress) public Ownable() {
        _tokenAddress = tokenAddress;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function tokenAddress() public view returns (address) {
        return _tokenAddress;
    }

    /**
     * @dev Throws if called by any account other than the token.
     */
    modifier onlyToken() {
        require(isToken(), "TokenOwnable: caller is not the token");
        _;
    }

     /**
     * @dev Returns true if the caller is the token.
     */
    function isToken() public view returns (bool) {
        return _msgSender() == _tokenAddress;
    }

}