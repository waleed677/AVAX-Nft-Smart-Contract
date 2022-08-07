// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./ERC721A.sol";
import "./MerkleProof.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract CaishenFinance is ERC721A, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;
    uint256 public costWL = 1  ether;
    uint256 public cost = 2  ether;
    uint256 public maxSupply = 5000;
    uint256 public maxMintAmountWL = 10;
    uint256 public maxMintAmountPublic = 10;
    uint256 public nftPerAddressLimitWL = 100;

    // Wallets to Withdraw
     address payable main = payable(0x6b101Fdb6eCCf0Bbc093f83E3F5A13507E257FA9);
     address payable secondary = payable(0x3452c37Dfb906F88d0bfE80e869b8A5aa8DD4786);

    uint256 mainPercentage = 85000;
    uint256 secondaryPercentage = 15000;
    uint256 baseDivisor = 100000;


    bool public revealed = true;
    mapping(address => uint256) public addressMintedBalanceWL;
    mapping(address => uint256) public addressMintedBalance;

    uint256 public currentState = 0;

    mapping(address => bool) public whitelistedAddresses;

    bytes32 public merkleRootWhitelist =
        0xc117da44cd8e89da7f09c9c2110a9e74054f2a2de428605e8103ff2c1560c4df;


    constructor() ERC721A("Caishen Finance ", "CNFT") {}

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(uint256 _mintAmount, bytes32[] calldata _merkleProof)
        public
        payable
    {
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");
        if (msg.sender != owner()) {
            require(currentState > 0, "the contract is paused");
            if (currentState == 1) {
                uint256 ownerMintedCount = addressMintedBalanceWL[msg.sender];
                require(
                    isWhitelisted(msg.sender, _merkleProof),
                    "user is not whitelisted"
                );
                require(
                    _mintAmount <= maxMintAmountWL,
                    "max mint amount per session exceeded"
                );
                require(
                    ownerMintedCount + _mintAmount <= maxMintAmountWL,
                    "max NFT per address exceeded"
                );
                require(
                    msg.value >= costWL * _mintAmount,
                    "insufficient funds"
                );
            }  else if (currentState == 2) {
                uint256 ownerMintedCount = addressMintedBalance[msg.sender];
                require(
                    _mintAmount <= maxMintAmountPublic,
                    "max mint amount per session exceeded"
                );
                require(
                    ownerMintedCount + _mintAmount <= maxMintAmountPublic,
                    "max NFT per address exceeded"
                );
                require(msg.value >= cost * _mintAmount, "insufficient funds");
            }
        }

        _safeMint(msg.sender, _mintAmount);
        if (currentState == 1) {
            addressMintedBalanceWL[msg.sender] += _mintAmount;
        }  else if (currentState == 2) {
            addressMintedBalance[msg.sender] += _mintAmount;
        }
    }

    function isWhitelisted(address _user, bytes32[] calldata _merkleProof)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_merkleProof, merkleRootWhitelist, leaf);
    }

    function mintableAmountForUser(address _user) public view returns (uint256) {
        if (currentState == 1) {
            return maxMintAmountWL - addressMintedBalanceWL[_user];
        } else if (currentState == 2) {
            return maxMintAmountPublic - addressMintedBalance[_user];
        }
        return 0;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function setNftPerAddressLimitWL(uint256 _limit) public onlyOwner {
        nftPerAddressLimitWL = _limit;
    }

    function setmaxMintAmountPublic(uint256 _newmaxMintAmount)
        public
        onlyOwner
    {
        maxMintAmountPublic = _newmaxMintAmount;
    }

    function setmaxMintAmountWL(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmountWL = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function pause() public onlyOwner {
        currentState = 0;
    }

    function setOnlyWhitelisted() public onlyOwner {
        currentState = 1;
    }

    function setPublic() public onlyOwner {
        currentState = 2;
    }

    function setWhitelistMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRootWhitelist = _merkleRoot;
    }


    function setPublicCost(uint256 _price) public onlyOwner {
        cost = _price;
    }

    function setWLCost(uint256 _price) public onlyOwner {
        costWL = _price;
    }

    function withdraw() public payable onlyOwner {
                // This will payout the owner the contract balance.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        // =============================================================================
        // =============================================================================

        uint256 totalBalance = address(this).balance;

        (bool mp, ) = payable(main).call{
            value: (totalBalance / baseDivisor) * mainPercentage
        }("");
        require(mp);

        (bool sp, ) = payable(secondary).call{
            value: (totalBalance / baseDivisor) * secondaryPercentage
        }("");
        require(sp);

    }
}
