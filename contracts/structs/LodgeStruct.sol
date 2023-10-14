// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library LodgeStruct{
    struct Build{
        // Create time
        uint64 createTime;
        // Vote quantities in competition
        uint64 competitionVotes;
        // Vote quantities get after competition
        uint64 extraVotes;
        // comment quantities
        uint64 totalComments;
    }

    struct Competition{
        uint256 totalPopularity;
        uint128 rewards;
    }

    struct Comment{
        address commentator;
        // can be 0
        uint128 replyComment;
        uint64 createTime; 
        uint64 votes;
        string content;
    }
}