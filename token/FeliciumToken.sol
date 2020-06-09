pragma solidity >=0.6.1;

import "../interface/IFeliciumToken.sol";
import "../abstract/TokenOwnable.sol";
import "../interface/FeliciumContract.sol";
import "./ERC777.sol";

contract FeliciumToken is ERC777, TokenOwnable, IFeliciumToken {

    mapping (address => mapping (address => uint256)) internal allowedContracts;

    constructor()
        ERC777("Felicium", "FEL", new address[](0)) TokenOwnable(address(this))
    public {
        _mint(_msgSender(), _msgSender(), 500000000 * 10 ** 18, "", "");
    }

    // IFeliciumToken

    /**
        Only Felicium B.V. should be able to register SmartContracts
        1) Gebruiker clickt een Smart Contract via de constructor in elkaar
        2) Smart contract wordt geupload door een allowedRegistrants (Service van Fel)
        3) Het smart contract registreert zich bij het Token (private register())
        4) Gebruiker kan hem activeren door authorizeSmartContract aan te roepen
        waarbij hij contract en totale reward meegeeft.
        6) Contract gaat executen en transfereert het approved bedrag naar zichzelf over,
        7) Contract is online
     */
    function registerSmartContract(address _smartContract, address _contractInitiator, uint256 _tokenDeposit) external
    override returns (bool) {
        require(_smartContract != address(0), "Invalid address");
        require(_contractInitiator != address(0), "Initiator unauthorized");
        require(_tokenDeposit > 0, "Deposited token amount needs to be greater than 0");
        allowedContracts[_smartContract][_contractInitiator] = _tokenDeposit;
        return true;
    }

    /**
    If registration of contract has been succesfully executed, then there should
    be a match under allowedContracts for the msg.sender
     */
    function authorizeSmartContract(address _smartContract, uint256 reward) external override {
        require(allowedContracts[_smartContract][msg.sender] == reward, "Invalid reward");

        allowedContracts[_smartContract][msg.sender] = 0;
        _approve(msg.sender, _smartContract, reward);
        emit AuthorizeSmartContract(msg.sender, _smartContract, reward);

        FeliciumContract fContract = FeliciumContract(_smartContract);
        fContract.executeContract();
    }
}