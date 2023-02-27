pragma solidity ^0.8.0;

/// @notice Interface for announcing when something is sent to a stealth address.
contract IERC5564Messenger {
  /// @dev Emitted when sending something to a stealth address.
  /// @dev See the `announce` method for documentation on the parameters.
  event Announcement (
    uint256 indexed schemeId, 
    address indexed stealthAddress, 
    bytes ephemeralPubKey, 
    bytes metadata
  );

  /// @dev Called by integrators to emit an `Announcement` event.
  /// @param schemeId The applied stealth address scheme (f.e. secp25k1).
  /// @param stealthAddress The computed stealth address for the recipient.
  /// @param ephemeralPubKey Ephemeral public key used by the sender.
  /// @param metadata An arbitrary field MUST include the view tag in the first byte.
  /// Besides the view tag, the metadata can be used by the senders however they like, 
  /// but the below guidelines are recommended:
  /// The first byte of the metadata MUST be the view tag.
  /// - When sending ERC-20 tokens, the metadata SHOULD be structured as follows:
  ///   - Byte 1 MUST be the view tag, as specified above.
  ///   - Bytes 2-5 are the method Id, which the hash of the canonical representation of the function to call.
  ///   - Bytes 6-25 are the token contract address.
  ///   - Bytes 26-57 are the amount of tokens being sent.
  /// - When approving a stealth address to spend ERC-20 tokens, the metadata SHOULD be structured as follows:
  ///   - Byte 1 MUST be the view tag, as specified above.
  ///   - Bytes 2-5 are 0xe1f21c67, which the signature for the ERC-20 approve method.
  ///   - Bytes 6-25 are the token address.
  ///   - Bytes 26-57 are the approval amount.
  /// - When sending ERC-721 tokens, the metadata SHOULD be structured as follows:
  ///   - Byte 1 MUST be the view tag, as specified above.
  ///   - Bytes 2-5 are the method Id.
  ///   - Bytes 6-25 are the token address.
  ///   - Bytes 26-57 are the token ID of the token being sent.
  function announce (
    uint256 schemeId, 
    address stealthAddress, 
    bytes memory ephemeralPubKey, 
    bytes memory metadata
  )
    external
  {
    emit Announcement(schemeId, stealthAddress, ephemeralPubKey, metadata);
  }
}