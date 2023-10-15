// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../structs/LodgeStruct.sol";

interface IBeaverCommunity {
    error CompetitionUnFinish();
    error DuplicateWithdraw();
    error DataTooLong();
    error InvalidParams();
    error InvalidVotes();
    error CallFromOutside();
    error LodgeBlocked();

    event NewLodge(uint256 indexed id, address indexed creator, uint64 indexed round, bool requireSubscribe, string content);

    event NewComment(uint256 indexed lodge, address indexed creator, uint128 indexed commentIndex, uint128 replyComment, uint64 votes, string content);

    event VoteInCompetition(uint256 indexed lodge, address indexed sponsor, uint64 votes);

    event VoteOutCompetition(uint256 indexed lodge, address indexed sponsor, uint64 votes);

    event WithdrawRewards(uint256 indexed lodge, address indexed to, uint256 rewards);

    event BatchWithdrawRewards(uint256[] lodges, address indexed to, uint256[] rewards);

    event WithdrawRoyalties(uint256 indexed lodge, address indexed to, uint256 royalties);

    event BatchWithdrawRoyalties(uint256[] lodges, address indexed to, uint256[] royalties);

    function currentRound() external view returns(uint64);

    function round(uint64 timestamp) external view returns(uint64);

    // build an beaver's construct
    function build(bool requireSubscribe, string calldata content) external;

    // vote to the beaver's lodge you like with a comment
    function vote(uint256 lodge, uint64 votes, uint128 replyComment, string memory content) external;

    // vote to the beaver's lodge you like
    function vote(uint256 lodge, uint64 votes) external;

    function calculatePopularity(uint64 votes) external pure returns(uint256);

    // get total rewards of a beaver buiding
    function lodgeRewards(uint256 lodge) external view returns (uint256);

    // get sponsor's rewards in a beaver buiding contains rewards fee
    function sponsorRewards(uint256 lodge, address sponsor) external view returns (uint256);

    // withdraw sponsor's rewards
    function withdrawRewards(uint256 lodge) external;

    function batchWithdrawRewards(uint256[] calldata lodges) external;

    // withdraw creator's royalties
    function withdrawRoyalties(uint256 lodge) external;

    function batchWithdrawRoyalties(uint256[] calldata lodges) external;

    function buildFee() external view returns(uint64);
}
