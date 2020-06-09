pragma solidity >=0.6.1;

interface IFeliciumToken {
    function authorizeSmartContract(address _smartContract, uint256 reward) external;

    function registerSmartContract(address _smartContract, address _contractInitiator, uint256 _tokenDeposit) external returns (bool);
    
    event AuthorizeSmartContract(address indexed _smartContract, address indexed _business, uint256 reward);
}