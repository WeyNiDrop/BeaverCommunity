// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./interfaces/IBeaverCommunity.sol";
import "./interfaces/ILodgeERC721.sol";
import "./structs/LodgeStruct.sol";
import "hardhat/console.sol";

contract BeaverCommunity is IBeaverCommunity, AccessControlUpgradeable, ReentrancyGuardUpgradeable{

    modifier OnlyOrigin {
        if (_msgSender() != tx.origin) {
            revert CallFromOutside();
        }
        _;
    }
    
    ILodgeERC721 public lodgeERC721;
    IERC20Upgradeable public woodCoin;
    uint256 public totalLodges;
    uint64 public initTime;
    uint64 public period;
    uint64 public totaRewardslPool;
    uint64 public voteFeeRate;
    uint64 public rewardsFeeRate;
    uint64 public rateToCreator;
    uint64 public rewardsReduceRate;
    uint64 public rewardsReduceRound;
    uint64 public totalFee;

    // round => competition info
    mapping(uint64 => LodgeStruct.Competition) public competitionMapping;

    // lodge => building info
    mapping(uint256 => LodgeStruct.Build) public buildMapping;

    // lodge => comment index => comment info
    mapping(uint256 => mapping(uint128 => LodgeStruct.Comment)) public commentMapping;

    // lodge => sponsor's address => votes
    mapping(uint256 => mapping(address => uint64)) public competitionVotesMapping;
    mapping(uint256 => mapping(address => uint64)) public extraVotesMapping;
    // lodge => sponsor's address => rewards withdraw status
    mapping(uint256 => mapping(address => bool)) public rewardsStatusMapping;
    // lodge => royalties withdraw status
    mapping(uint256 => bool) public royaltiesStatusMapping;

    // subscription arguments
    // lodge => only subscriber look
    mapping(uint256 => bool) public subscriptionMapping;
    // user => subscription price
    mapping(address => uint64) public subscriptionPriceMapping;

    
    function initialize(address lodgeERC721_, address woodCoin_, uint64 period_) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        initTime = uint64(block.timestamp);
        lodgeERC721 = ILodgeERC721(lodgeERC721_);
        woodCoin = IERC20Upgradeable(woodCoin_);
        period = period_;
        totaRewardslPool = 1e9 - 1e6;
        voteFeeRate = 500;
        rewardsFeeRate = 100;
        rateToCreator = 500;
        rewardsReduceRate = 8000;
        rewardsReduceRound = 200;
    }

    function currentRound() public view returns(uint64){
        return round(uint64(block.timestamp));
    }

    function round(uint64 timestamp) public view returns(uint64){
        // console.log("timestamp: ", timestamp);
        return (timestamp - initTime)/period;
    }

    // build an beaver's construct
    function build(bool requireSubscribe, string calldata content) external nonReentrant OnlyOrigin{
        if (bytes(content).length > 2048) {
            revert DataTooLong();
        }
        uint64 fee = buildFee();
        if(fee > 0){
            totalFee += fee;
            SafeERC20Upgradeable.safeTransferFrom(woodCoin, _msgSender(), address(this), fee);
        }
        totalLodges++;
        // mint nft
        lodgeERC721.mint(_msgSender(), totalLodges, content);
        uint64 createTime = uint64(block.timestamp);
        buildMapping[totalLodges].createTime = createTime;
        if(requireSubscribe){
            subscriptionMapping[totalLodges] = true;
        }
        emit NewLodge(totalLodges, _msgSender(), round(createTime), requireSubscribe, content);
        // give airdrop to the first 10000 lodge creator
        if (totalLodges <= 1e5) {
            SafeERC20Upgradeable.safeTransfer(woodCoin, _msgSender(), 10);
        }
        console.log("beaver id:", totalLodges);
    }

    // vote to the beaver's build you like with a comment
    function vote(uint256 lodge, uint64 votes, uint128 replyComment, string memory content) external nonReentrant OnlyOrigin{
        _vote(lodge, votes, replyComment, content);
    }

    // vote to the beaver's build you like
    function vote(uint256 lodge, uint64 votes) external nonReentrant OnlyOrigin{
        _vote(lodge, votes, 0, "");
    }

    
    function _vote(uint256 lodge, uint64 votes, uint128 replyComment, string memory content) private{
        if (votes == 0) {
            revert InvalidVotes();
        }
        if (lodgeERC721.blacklist(lodge)) {
            revert LodgeBlocked();
        }
        LodgeStruct.Build storage beaverBuild = buildMapping[lodge];
        if (bytes(content).length > 0) {
            // add comment
            beaverBuild.totalComments = beaverBuild.totalComments + 1;
            _addComment(lodge, beaverBuild.totalComments, votes, replyComment, content);
        }
        // judge competition status
        uint64 competitionRound = round(beaverBuild.createTime);
        if(competitionRound == currentRound() && !subscriptionMapping[lodge]){
            SafeERC20Upgradeable.safeTransferFrom(woodCoin, _msgSender(), address(this), votes);
            LodgeStruct.Competition storage competition = competitionMapping[competitionRound];
            competition.totalPopularity = competition.totalPopularity - calculatePopularity(beaverBuild.competitionVotes);
            console.log("votes: ", votes);
            beaverBuild.competitionVotes += votes;
            // init rewards
            if (competition.rewards == 0) {
                uint64 baseRewards = uint64(_roundRewards(competitionRound));
                if (baseRewards > totaRewardslPool) {
                    baseRewards = totaRewardslPool;
                }
                totaRewardslPool -= baseRewards;
                competition.rewards = baseRewards + votes;
            }else {
                competition.rewards += votes;
            }
            competition.totalPopularity = competition.totalPopularity + calculatePopularity(beaverBuild.competitionVotes);

            competitionVotesMapping[lodge][_msgSender()] += votes;

            emit VoteInCompetition(lodge, _msgSender(), votes);
            
        }else {
            beaverBuild.extraVotes += votes;
            // fee
            uint64 fee = votes*voteFeeRate/10000;
            if(fee > 0){
                totalFee += fee;
            }
            SafeERC20Upgradeable.safeTransferFrom(woodCoin, _msgSender(), IERC721Upgradeable(address(lodgeERC721)).ownerOf(lodge), votes - fee);
            extraVotesMapping[lodge][_msgSender()] += votes;
            emit VoteOutCompetition(lodge, _msgSender(), votes);
        }

        console.log("build competitionVotes: ", beaverBuild.competitionVotes);
        console.log("build extraVotes: ", beaverBuild.extraVotes);
        console.log("build popularity: ", calculatePopularity(beaverBuild.competitionVotes));
        console.log("competition rewards: ", competitionMapping[competitionRound].rewards);
        console.log("competition popularity: ", competitionMapping[competitionRound].totalPopularity);

    }

    function calculatePopularity(uint64 votes) public pure returns(uint256){
        return 100* votes + 3*votes*votes;
    }

    function _addComment(uint256 lodge, uint128 commentIndex, uint64 votes, uint128 replyComment, string memory content) private{
        if (bytes(content).length > 1024) {
            revert DataTooLong();
        }
        if(replyComment > buildMapping[lodge].totalComments){
            revert InvalidParams();
        }
        LodgeStruct.Comment storage comment = commentMapping[lodge][commentIndex];
        comment.commentator = _msgSender();
        if (replyComment != 0) {
            comment.replyComment = replyComment;
        }
        comment.votes = votes;
        comment.createTime = uint64(block.timestamp);
        comment.content = content;
        emit NewComment(lodge, _msgSender(), commentIndex, replyComment, votes, content);
    }

    // get total rewards of a beaver buiding
    function lodgeRewards(uint256 lodge) public view returns (uint256){
        uint popularity = calculatePopularity(buildMapping[lodge].competitionVotes);
        uint64 buidingRound = round(buildMapping[lodge].createTime);

        return competitionMapping[buidingRound].rewards *  popularity / competitionMapping[buidingRound].totalPopularity;
    }
    // get sponsor's rewards in a beaver buiding
    function sponsorRewards(uint256 lodge, address sponsor) public view returns (uint256) {
        uint votes = competitionVotesMapping[lodge][sponsor];
        return (lodgeRewards(lodge) * votes / buildMapping[lodge].competitionVotes) *(10000 - rateToCreator)/ 10000;
    }

    // withdraw sponsor's rewards
    function withdrawRewards(uint256 lodge) external nonReentrant{
        emit WithdrawRewards(lodge, _withdrawRewards(lodge), _msgSender());
    }
    
    function _withdrawRewards(uint256 lodge) private returns(uint256){
        if(rewardsStatusMapping[lodge][_msgSender()]){
            revert DuplicateWithdraw();
        }
        if(round(buildMapping[lodge].createTime) == currentRound()){
            revert CompetitionUnFinish();
        }
        rewardsStatusMapping[lodge][_msgSender()] = true;
        uint64 rewards = uint64(sponsorRewards(lodge, _msgSender()));
        
        // fee
        uint64 fee = rewards * rewardsFeeRate/10000;
        if(fee > 0){
            console.log("rewards fee:", fee);
            totalFee += fee;
        }
        console.log("sponsor rewards:", rewards - fee);
        SafeERC20Upgradeable.safeTransfer(woodCoin, _msgSender(), rewards - fee);
        return rewards;
    }

    function batchWithdrawRewards(uint256[] calldata lodges) external nonReentrant{
        uint256[] memory rewardsArray = new uint256[](lodges.length);
        for (uint i = 0; i < lodges.length; i++) {
            rewardsArray[i] = _withdrawRewards(lodges[i]);
        }
        emit BatchWithdrawRewards(lodges, rewardsArray, _msgSender());
    }

    // withdraw creator's royalties
    function withdrawRoyalties(uint256 lodge) external nonReentrant{
        emit WithdrawRoyalties(lodge, _withdrawRoyalties(lodge), _msgSender());
    }

    function _withdrawRoyalties(uint256 lodge) private returns(uint256){
        if(royaltiesStatusMapping[lodge]){
            revert DuplicateWithdraw();
        }
        if(round(buildMapping[lodge].createTime) == currentRound()){
            revert CompetitionUnFinish();
        }
        if (lodgeERC721.blacklist(lodge)) {
            revert LodgeBlocked();
        }
        royaltiesStatusMapping[lodge] = true;
        uint royalties = lodgeRewards(lodge) * rateToCreator / 10000;
        if (royalties > 0) {
            SafeERC20Upgradeable.safeTransfer(woodCoin, IERC721Upgradeable(address(lodgeERC721)).ownerOf(lodge), royalties);
        }
        return royalties;
    }

    function batchWithdrawRoyalties(uint256[] calldata lodges) external nonReentrant{
        uint256[] memory royaltiesArray = new uint256[](lodges.length);
        for (uint i = 0; i < lodges.length; i++) {
            royaltiesArray[i] = _withdrawRoyalties(lodges[i]);
        }
        emit BatchWithdrawRoyalties(lodges, royaltiesArray, _msgSender());
    }

    function _roundRewards(uint64 round_) public view returns(uint256){
        uint256 baseRewards = 1e6;
        uint cycle = round_ / rewardsReduceRound;
        return  baseRewards * (uint256(rewardsReduceRate) ** cycle)/(10000 ** cycle);
    }

    function _circulatingWoods() internal view returns(uint64){
        return 9e8 - totaRewardslPool;
    }

    function buildFee() public view returns(uint64){
        return (_circulatingWoods())/1e6;
    }

    function withdrawFee(address to, uint64 amount) external onlyRole(DEFAULT_ADMIN_ROLE){
        totalFee -= amount;
        SafeERC20Upgradeable.safeTransfer(woodCoin, to, amount);
    }
}