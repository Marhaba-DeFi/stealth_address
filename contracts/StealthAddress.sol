
pragma solidity ^0.8.17;

import "./IERC5564Messenger.sol";

contract StealthAddress {   
    IERC5564Messenger public messenger;

    /// @notice Generates a stealth address from a stealth meta address.
    /// @param stealthMetaAddress The recipient's stealth meta-address.
    /// @return stealthAddress The recipient's stealth address.
    /// @return ephemeralPubKey The ephemeral public key used to generate the stealth address.
    /// @return viewTag The view tag derived from the shared secret.
    function generateStealthAddress(bytes memory stealthMetaAddress)
        external
        view
        returns (address stealthAddress, bytes memory ephemeralPubKey, bytes1 viewTag)
    {
        // Step 1: Generate a random 32-byte entropy ephemeral private key pephemeral.
        bytes32 pephemeral = keccak256(abi.encodePacked(block.timestamp, msg.sender, blockhash(block.number-1)));

        // Step 2: Derive the ephemeral public key Pephemeral from pephemeral.
        bytes memory ephemeralPubKeyBytes = Secp256k1.derivePublicKey(phemeral);
        bytes32 x;
        assembly {
            x := mload(add(ephemeralPubKeyBytes, 32))
        }
        bytes32 y;
        assembly {
            y := mload(add(ephemeralPubKeyBytes, 64))
        }
        uint8 parity = uint8(y) % 2 == 0 ? 0x02 : 0x03;
        ephemeralPubKey = abi.encodePacked(parity, x);

        // Step 3: Parse the spending and viewing public keys, Pspend and Pview, from the stealth meta-address.
        bytes32 Pspend;
        bytes32 Pview;
        assembly {
            Pspend := mload(add(stealthMetaAddress, 20))
            Pview := mload(add(stealthMetaAddress, 52))
        }

        // Step 4: A shared secret s is computed as s = pephemeral * Pview.
        bytes32 s = Secp256k1.multiplyModN(phemeral, Pview);

        // Step 5: The secret is hashed sh = h(s).
        bytes32 sh = keccak256(abi.encodePacked(s));

        // Step 6: The view tag v is extracted by taking the most significant byte sh[0].
        viewTag = sh[0];

        // Step 7: Multiply the hashed shared secret with the generator point Sh = sh * G.
        bytes memory ShBytes = Secp256k1.multiplyByG(sh);

        // Step 8: The recipient’s stealth public key is computed as Pstealth = Pspend + Sh.
        bytes32 Pstealth = Pspend + bytesToBytes32(ShBytes);

        // Step 9: The recipient’s stealth address astealth is computed as pubkeyToAddress(Pstealth).
        stealthAddress = string(abi.encodePacked("st:eth:0x", bytesToHex(Pspend), bytesToHex(Pview)));
        
        return (stealthAddress, ephemeralPubKey, viewTag);
    }

    
    /// @notice Returns true if funds sent to a stealth address belong to the recipient who controls
    /// the corresponding spending key.
    /// @param stealthAddress The recipient's stealth address.
    /// @param ephemeralPubKey The ephemeral public key used to generate the stealth address.
    /// @param viewingKey The recipient's viewing private key.
    /// @param spendingPubKey The recipient's spending public key.
    /// @return True if funds sent to the stealth address belong to the recipient.
    function checkStealthAddress(
        address stealthAddress,
        bytes memory ephemeralPubKey,
        bytes memory viewingKey,
        bytes memory spendingPubKey
    ) external view returns (bool) {
        // Parse the public keys from their byte array representation.
        bytes memory prefix = "\x04";
        bytes memory x = new bytes(32);
        bytes memory y = new bytes(32);
        assembly {
            mstore(add(x, 32), mload(add(spendPubKey, 32)))
            mstore(add(y, 32), mload(add(add(spendPubKey, 32), 32)))
        }
        bytes memory spendPubKeyBytes = abi.encodePacked(prefix, x, y);
        assembly {
            mstore(add(x, 32), mload(add(viewingKey, 32)))
            mstore(add(y, 32), mload(add(add(viewingKey, 32), 32)))
        }
        bytes memory viewingKeyBytes = abi.encodePacked(prefix, x, y);

        // Compute the shared secret and hashed shared secret.
        uint256[2] memory ephemeralPoint = fromEthereumBytes(ephemeralPubKey);
        uint256[2] memory viewPoint = fromEthereumBytes(viewingKeyBytes);
        uint256[2] memory sharedSecret = scalarMult(viewPoint, ephemeralPoint);
        bytes32 hashedSecret = keccak256(abi.encodePacked(sharedSecret));

        // Multiply the hashed shared secret with the generator point.
        uint256[2] memory generatorPoint = getGenerator();
        uint256[2] memory hashPoint = scalarMult(generatorPoint, uint256(hashedSecret));
        
        // Parse the spending public key.
        uint256[2] memory spendPoint = fromEthereumBytes(spendPubKeyBytes);
        
        // Add the hash point to the spending public key to get the stealth public key.
        uint256[2] memory stealthPoint = addPoints(spendPoint, hashPoint);
        
        // Compute the derived stealth address.
        address derivedStealthAddress = pubkeyToAddress(stealthPoint);

        // Compare the derived stealth address with the provided stealth address.
        return stealthAddress == derivedStealthAddress;
    }



    /// @notice Computes the stealth private key for a stealth address.
    /// @param stealthAddress The expected stealth address.
    /// @param ephemeralPubKey The ephemeral public key used to generate the stealth address.
    /// @param spendingKey The recipient's spending private key.
    /// @return stealthKey The stealth private key corresponding to the stealth address.
    /// @dev The stealth address input is not strictly necessary, but it is included so the method
    /// can validate that the stealth private key was generated correctly.
    function computeStealthKey(
    address stealthAddress,
    bytes memory ephemeralPubKey,
    bytes memory spendingKey
    ) external view returns (bytes memory) {
        // Concatenate the stealth address and the ephemeral public key
        bytes memory concatenatedData = abi.encodePacked(stealthAddress, ephemeralPubKey);
        
        // Hash the concatenated data using keccak256
        bytes32 hashedData = keccak256(concatenatedData);
        
        // Derive the stealth key from the spending key and the hashed data
        bytes memory stealthKey = abi.encodePacked(keccak256(abi.encodePacked(spendingKey, hashedData)));
        
        // Validate that the computed stealth key corresponds to the expected stealth address
        address computedAddress = address(uint160(uint256(keccak256(abi.encodePacked(stealthKey, ephemeralPubKey))))); 
        require(computedAddress == stealthAddress, "Invalid stealth address");
        
        return stealthKey;
    }

}
