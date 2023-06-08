// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GoldenTicketNFT is ERC721, Pausable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    // cost of individual NFTs in collection
    uint256 public cost = 350;
    address public feeWallet;
    Counters.Counter public _tokenIdCounter;
    IERC20 USDT;
    string public baseTokenURI;

    constructor(address _USDT) ERC721("Golden Ticket", "GT") {
        feeWallet = msg.sender;
        USDT = IERC20(_USDT);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /*
     * @notice function to change payment amount
     * @param _Token, the address of new payment amount
     */
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    /*
     * @notice function to change payment token
     * @param _Token, the address of new payment token
     */
    function changePaymentToken(address _Token) public onlyOwner {
        USDT = IERC20(_Token);
    }

    /*
     * @notice function to burn an NFT
     * @param tokenId, the id of the NFT
     */
    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory base = _baseURI();

        return bytes(base).length > 0 ? string(abi.encodePacked(base)) : "";
    }

    /*
     * @notice function to change fee wallet
     */
    function ChangefeeAddress(address _feeWallet) external onlyOwner {
        require(_feeWallet != address(0), "!nonzero");
        feeWallet = _feeWallet;
    }

    /*
     * @notice function to mint an NFT
     * @param
     */
    function safeMint() public {
        require(balanceOf(msg.sender) == 0, "User already owns an NFT");
        uint256 balbefore = IERC20(USDT).balanceOf(feeWallet);
        IERC20(USDT).transferFrom(msg.sender, feeWallet, cost * 10 ** 18);
        uint256 balafter = IERC20(USDT).balanceOf(feeWallet);

        require(
            balafter - balbefore == cost * 10 ** 18,
            "USDT not sent properly"
        );

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
            from == address(0x0000000000000000000000000000000000000000) ||
                to == address(0x0000000000000000000000000000000000000000),
            "Transfer not allowed"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}