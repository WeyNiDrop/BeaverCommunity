// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/ILodgeERC721.sol";

contract LodgeERC721 is ILodgeERC721, ERC721RoyaltyUpgradeable, AccessControlUpgradeable{
    bytes32 public constant COMMUNITY_ROLE = keccak256("COMMUNITY_ROLE");
    mapping(uint256 => string) public contentMapping;
    mapping(uint256 => bool) public blacklist;
    string public baseURI;
    uint256 public totalSupply;

    /**
     * @dev Initialization constructor related parameters
     */
    function initialize(string calldata name_, string calldata symbol_) initializer public {
        __AccessControl_init_unchained();
        __ERC721_init(name_, symbol_);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721RoyaltyUpgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(address to, uint256 id, string calldata content) external onlyRole(COMMUNITY_ROLE) override{
        _mint(to, id);
        _setTokenRoyalty(id, to, 500);
        contentMapping[id] = content;
        totalSupply = id;
        emit LodgeMinted(to, id, content);
    }  

    function setBaseURI(string calldata baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE){
        baseURI = baseURI_;
    }

    function ban(uint256 id, string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE){
        delete contentMapping[id];
        blacklist[id] = true;
        emit BlockLodge(id, reason);
    }
}