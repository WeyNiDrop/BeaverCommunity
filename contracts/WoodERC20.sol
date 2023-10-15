// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WoodERC20 is ERC20, Ownable {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
    
    function mint(address community) external onlyOwner{
        
        _mint(community, 1e9);

        if (totalSupply() > 1e9) {
            revert();
        }
    }
}