// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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


contract DripStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice Info of each Staking user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards. See explanation below.
    ///
    /// We do some fancy math here. Basically, any point in time, the amount of DRIPs
    /// entitled to a user but is pending to be distributed is:
    ///
    ///   pending reward = (user share * pool.accDripPerShare) - user.rewardDebt
    ///
    ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    ///   1. The pool's `accDripPerShare` (and `lastRewardBlock`) gets updated.
    ///   2. User receives the pending reward sent to his/her address.
    ///   3. User's `amount` gets updated. Pool's `totalBoostedShare` gets updated.
    ///   4. User's `rewardDebt` gets updated.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 boostMultiplier;
    }

    // @notice Accumulated DRIPs per share, times 1e12.
    uint256 public accDripPerShare;
    // @notice Last block number that pool update action is executed.
    uint256 public lastRewardBlock;
    // @notice The total amount of user shares in each pool. After considering the share boosts.
    uint256 public totalBoostedShare;
    // @notice The DRIP amount to be distributed every block.
    uint256 public dripPerBlock;
    

    /// @notice Address of the LP token for each MCV2 pool.
    IBEP20 public lpToken;
    /// @notice Address of DRIP contract.
    IBEP20 public DRIP;
    /// @notice Address of Vault contract address.
    address public vaultAddress;

    /// @notice 
    uint256 public constant ACC_DRIP_PRECISION = 1e18;
    /// @notice 
    uint256 public constant BOOST_PRECISION = 1e12;
    /// @notice Info of each pool user.
    mapping(address => UserInfo) public userInfo;
    /// @notice Match multiplier to each user.
    mapping(address => uint256) public userMultiplier;
    
    event UpdatePool(uint256 lastRewardBlock, uint256 lpSupply, uint256 accDripPerShare);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) {
        DRIP    = IBEP20(0x20f663CEa80FaCE82ACDFA3aAE6862d246cE0333);
        lpToken = IBEP20(0xB17E674a4B28958A0eF77E608B4fE94c23AceE29);
        vaultAddress = 0xBFF8a1F9B5165B787a00659216D7313354D25472;
    }

    /// @notice View function for checking pending DRIP rewards.
    /// @param _user Address of the user.
    function pendingDrip(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        uint256 accPerShare = accDripPerShare;
        uint256 lpSupply = totalBoostedShare;


        if (block.number > lastRewardBlock && totalBoostedShare != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 dripReward = multiplier.mul(dripPerBlock);
            accPerShare = accPerShare.add(dripReward.mul(ACC_DRIP_PRECISION).div(lpSupply));
        }

        uint256 boostedAmount = user.amount.mul(userMultiplier[_user]).div(BOOST_PRECISION);
        return boostedAmount.mul(accPerShare).sub(user.rewardDebt);
    }

    /// @notice Update reward variables for the given pool.
    function updatePool() public {
        if (block.number > lastRewardBlock) {
            uint256 lpSupply = totalBoostedShare;

            if (lpSupply > 0 ) {
                uint256 multiplier = block.number.sub(lastRewardBlock);
                uint256 dripReward = multiplier.mul(dripPerBlock);

                accDripPerShare = accDripPerShare.add((dripReward.mul(ACC_DRIP_PRECISION).div(lpSupply)));
            }
            lastRewardBlock = block.number;

            emit UpdatePool(lastRewardBlock, lpSupply, accDripPerShare);
        }
    }


    /// @notice Deposit LP tokens to pool.
    /// @param _amount Amount of LP tokens to deposit.
    function deposit(uint256 _amount, uint256 multiplier) external nonReentrant {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];

        if (user.amount > 0) {
            settlePendingDrip(msg.sender, multiplier);
        }

        if (_amount > 0) {
            uint256 before = lpToken.balanceOf(address(this));
            lpToken.transferFrom(msg.sender, address(this), _amount);
            _amount = lpToken.balanceOf(address(this)).sub(before);
            user.amount = user.amount.add(_amount);

            // Update total boosted share.
            totalBoostedShare = totalBoostedShare.add(_amount.mul(multiplier).div(BOOST_PRECISION));
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(accDripPerShare).div(
            ACC_DRIP_PRECISION
        );

        emit Deposit(msg.sender, _amount);
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _amount Amount of LP tokens to withdraw.
    function withdraw(uint256 _amount) external nonReentrant {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount >= _amount, "withdraw: Insufficient");

        uint256 multiplier = userMultiplier[msg.sender];

        settlePendingDrip(msg.sender, multiplier);

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            lpToken.transfer(msg.sender, _amount);
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(accDripPerShare).div(
            ACC_DRIP_PRECISION
        );
        totalBoostedShare = totalBoostedShare.sub(
            _amount.mul(multiplier).div(BOOST_PRECISION)
        );

        emit Withdraw(msg.sender, _amount);
    }
  
    /// @notice Settles, distribute the pending DRIP rewards for given user.
    /// @param _user The user address for settling rewards.
    /// @param _boostMultiplier The user boost multiplier in specific pool.
    function settlePendingDrip(
        address _user,
        uint256 _boostMultiplier
    ) internal {
        UserInfo memory user = userInfo[_user];

        uint256 boostedAmount = user.amount.mul(_boostMultiplier).div(BOOST_PRECISION);
        uint256 accDrip = boostedAmount.mul(accDripPerShare).div(ACC_DRIP_PRECISION);
        uint256 pending = accDrip.sub(user.rewardDebt);
        
        // SafeTransfer DRIP
        _safeTransfer(_user, pending);
    }

    
    /// @notice Safe Transfer DRIP.
    /// @param _to The DRIP receiver address.
    /// @param _amount transfer DRIP amounts.
    function _safeTransfer(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            uint256 vaultBalance = DRIP.balanceOf(vaultAddress);
            // Check whether Tax Vault has enough DRIP. If not, Mint from the Drip contract.
            if (vaultBalance.div(10) < _amount) {
                DRIP.mint(address(this), _amount - vaultBalance.div(10));
            }

            IVault(vaultAddress).withdraw(vaultBalance);

            DRIP.transfer(address(0), vaultBalance.sub(vaultBalance.div(10)));            
            DRIP.transfer(_to, _amount);
        }
    }
    
}