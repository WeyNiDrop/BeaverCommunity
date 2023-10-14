// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILodgeERC721{
    event LodgeMinted(address indexed to, uint256 indexed id, string content);

    event BlockLodge(uint256 indexed id, string reason);

    function blacklist(uint256 id) external view returns(bool);

    function mint(address to, uint256 id, string calldata content) external;

    function totalSupply() external view returns(uint256);
}

