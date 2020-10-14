// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "./StakePool.sol";

/**
 * @dev https://bscswap.com
 * DEGEN will be halved at each period.
 * Forked from https://github.com/milk-protocol/stakecow-contracts-bsc/blob/master/contracts/FomoCow.sol
 */

 // SPDX-License-Identifier: MIT

 pragma solidity ^0.6.12;

 /**
  * @dev https://bscswap.com
  * DEGEN will be halved at each period.
  * Forked from https://github.com/milk-protocol/stakecow-contracts-bsc/blob/master/contracts/FomoCow.sol
  */

 contract BurnPool is StakePool {
     IERC20 public degenToken;

     // Halving period in seconds, should be defined as 1 day
     uint256 public halvingPeriod = 86400;
     // Total reward in 18 decimal
     uint256 public totalreward;
     // Starting timestamp for Degen Staking Pool
     uint256 public starttime;
     // The timestamp when stakers should be allowed to withdraw
     uint256 public stakingtime;
     uint256 public eraPeriod = 0;
     uint256 public rewardRate = 0;
     uint256 public lastUpdateTime;
     uint256 public rewardPerTokenStored;
     uint256 public totalRewards = 0;

     mapping(address => uint256) public userRewardPerTokenPaid;
     mapping(address => uint256) public rewards;

     event RewardAdded(uint256 reward);
     event Staked(address indexed user, uint256 amount);
     event Withdrawn(address indexed user, uint256 amount);
     event RewardPaid(address indexed user, uint256 reward);

     modifier updateReward(address account) {
         rewardPerTokenStored = rewardPerToken();
         lastUpdateTime = lastTimeRewardApplicable();
         if (account != address(0)) {
             rewards[account] = earned(account);
             userRewardPerTokenPaid[account] = rewardPerTokenStored;
         }
         _;
     }

     constructor(address _depositToken, address _degenToken, uint256 _totalreward, uint256 _starttime, uint256 _stakingtime) public {
         super.initialize(_depositToken);
         degenToken = IERC20(_degenToken);

         starttime = _starttime;
         stakingtime = _stakingtime;
         notifyRewardAmount(_totalreward.mul(50).div(100));
     }

     function lastTimeRewardApplicable() public view returns (uint256) {
         return Math.min(block.timestamp, eraPeriod);
     }

     function rewardPerToken() public view returns (uint256) {
         if (totalSupply() == 0) {
             return rewardPerTokenStored;
         }
         return
             rewardPerTokenStored.add(
                 lastTimeRewardApplicable()
                     .sub(lastUpdateTime)
                     .mul(rewardRate)
                     .mul(1e18)
                     .div(totalSupply())
             );
     }

     function earned(address account) public view returns (uint256) {
         return
             balanceOf(account)
                 .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                 .div(1e18)
                 .add(rewards[account]);
     }

     function stake(uint256 amount) public updateReward(msg.sender) checkhalve checkStart{
         require(amount > 0, "ERROR: Cannot stake 0 Token");
         super._stake(amount);
         emit Staked(msg.sender, amount);
     }

     function getReward() public updateReward(msg.sender) checkhalve checkStart stakingTime{
         uint256 reward = earned(msg.sender);
         if (reward > 0) {
             rewards[msg.sender] = 0;
             degenToken.safeTransfer(msg.sender, reward);
             emit RewardPaid(msg.sender, reward);
             totalRewards = totalRewards.add(reward);
         }
     }

     modifier checkhalve(){
         if (block.timestamp >= eraPeriod) {
             totalreward = totalreward.mul(50).div(100);

             rewardRate = totalreward.div(halvingPeriod);
             eraPeriod = block.timestamp.add(halvingPeriod);
             emit RewardAdded(totalreward);
         }
         _;
     }

     modifier checkStart(){
         require(block.timestamp > starttime,"ERROR: Not start");
         _;
     }

     modifier stakingTime(){
         require(block.timestamp >= stakingtime,"ERROR: Withdrawals open after 24 hours from the beginning");
         _;
     }

     function notifyRewardAmount(uint256 reward)
         internal
         updateReward(address(0))
     {
         if (block.timestamp >= eraPeriod) {
             rewardRate = reward.div(halvingPeriod);
         } else {
             uint256 remaining = eraPeriod.sub(block.timestamp);
             uint256 leftover = remaining.mul(rewardRate);
             rewardRate = reward.add(leftover).div(halvingPeriod);
         }
         totalreward = reward;
         lastUpdateTime = block.timestamp;
         eraPeriod = block.timestamp.add(halvingPeriod);
         emit RewardAdded(reward);
     }
 }
