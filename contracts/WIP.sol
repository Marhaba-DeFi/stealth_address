pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

/**
 * @title StealthVault
 * @dev A contract that enables stealth transactions with a Merkle tree
 */
contract StealthVault is Ownable {
    bytes32 public merkleRoot; // The root hash of the Merkle tree
    mapping(bytes32 => bool) public usedHashes; // A mapping to keep track of used hashes
    
    event NewMerkleRoot(bytes32 indexed merkleRoot); // Event emitted when the Merkle root is updated
    
    /**
     * @dev Checks if the given stealth address is valid
     * @param _hash The hash of the recipient's public key
     * @param _signature The signature of the transaction
     * @param _secret The secret used to derive the recipient's meta address
     * @return A boolean indicating whether the given stealth address is valid
     */
    function checkStealthAddress(bytes32 _hash, bytes memory _signature, bytes32 _secret) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(_hash, _secret));
        address signer = ECDSA.recover(message, _signature);
        bytes32 hash = keccak256(abi.encodePacked(signer));
        return MerkleProof.verify(_hash, merkleRoot, hash);
    }

    /**
     * @dev Inserts a hash into the used hashes mapping
     * @param _hash The hash to be inserted
     */
    function insert(bytes32 _hash) public onlyOwner {
        require(!usedHashes[_hash], "Hash already used");
        usedHashes[_hash] = true;
    }

    /**
     * @dev Updates the Merkle root
     * @param _newMerkleRoot The new Merkle root to be set
     */
    function updateMerkleRoot(bytes32 _newMerkleRoot) public onlyOwner {
        merkleRoot = _newMerkleRoot;
        emit NewMerkleRoot(merkleRoot);
    }

    /**
     * @dev Generates a recipient meta address
     * @param _hash The hash of the recipient's public key
     * @param _secret The secret used to derive the recipient's meta address
     * @param _rootKey The root key used to derive recipient meta addresses
     * @return The recipient meta address
     */
    function generateRecipientMetaAddress(bytes32 _hash, bytes32 _secret, bytes32 _rootKey) public pure returns (bytes32) {
        bytes32 derivedKey = keccak256(abi.encodePacked(_rootKey, _secret));
        return keccak256(abi.encodePacked(_hash, derivedKey));
    }

    /**
    * @dev Withdraw funds to a recipient who has provided a valid signature and secret for a stealth address.
    * @param _hash The hash of the stealth address.
    * @param _signature The signature provided by the sender.
    * @param _secret The secret provided by the recipient.
    * @param _amount The amount to be withdrawn.
    */
    function withdraw(bytes32 _hash, bytes memory _signature, bytes32 _secret, uint256 _amount) public {
        // Verify that the provided stealth address is valid
        require(checkStealthAddress(_hash, _signature, _secret), "Invalid stealth address");

        // Derive the recipient meta address from the provided secret and verify that it hasn't been used before
        bytes32 recipientMetaAddress = generateRecipientMetaAddress(_hash, _secret);
        require(!usedHashes[recipientMetaAddress], "Hash already used");
        usedHashes[recipientMetaAddress] = true;

        // Calculate the recipient address from the recipient meta address
        address payable recipientAddress = address(uint160(uint256(recipientMetaAddress)));

        // Check contract balance and transfer funds to recipient
        require(address(this).balance >= _amount, "Insufficient balance");
        recipientAddress.transfer(_amount);
    }
}