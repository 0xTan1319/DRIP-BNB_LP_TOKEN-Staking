// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBEP20.sol";
import "./interfaces/IVault.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Treasury is Ownable {
    using SafeMath for uint256;

    IBEP20 internal DRIP;  // address of the BEP20 token traded on this contract
    IVault internal Vault; // address of the Vault contract 

    address public stakingContract;
    uint256 public lastDepositTime;


    // We receive Drip token on this vault
    constructor() Ownable(_msgSender()) {
        DRIP = IBEP20(0x20f663CEa80FaCE82ACDFA3aAE6862d246cE0333);
        Vault = IVault(0xBFF8a1F9B5165B787a00659216D7313354D25472);
    }


    function setStakingContract(address _stakingContract) public onlyOwner {
        require(_stakingContract != address(0) && _stakingContract != stakingContract, "Not Zero Address");
        stakingContract = _stakingContract;
    }
    
    function deposit() public {
        if (lastDepositTime == 0) {
            lastDepositTime = block.timestamp;
        } else {
            require(
                lastDepositTime + 86000 < block.timestamp 
                  && block.timestamp < lastDepositTime + 87000, 
                "Invalid Time Range");
        }

        uint256 taxBalance = DRIP.balanceOf(stakingContract);
        Vault.withdraw(taxBalance);

        uint256 pureBalance = taxBalance.div(10);

        DRIP.transfer(address(0), taxBalance.sub(pureBalance));

        uint256 treasuryBalance = DRIP.balanceOf(address(this));

        DRIP.transfer(stakingContract, treasuryBalance.div(100));

        lastDepositTime = block.timestamp;
    }
}
