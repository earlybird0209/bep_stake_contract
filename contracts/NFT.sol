// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, Pausable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIdCounter;
    IERC20 USDT;

    constructor(address _USDT) ERC721("MyToken", "MTK") {
        USDT = IERC20(_USDT);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint() public {
        require(balanceOf(msg.sender) == 0, "User already owns an NFT");
        bool success = IERC20(USDT).transferFrom(
            msg.sender,
            address(this),
            350 * 10 ** 18
        );
        require(success);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        require(
            from == address(0x0000000000000000000000000000000000000000),
            "Transfer not allowed"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
