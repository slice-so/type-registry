// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TypeRegistrationParams} from "../types/TypeRegistrationParams.sol";
import {BaseType} from "../types/TypeComponent.sol";

/// @title Type Registry Interface
interface ITypeRegistry {
    /// @notice Reverts when a caller other than the registered owner attempts to update an entry.
    /// @param registrant Current registrant for the selector.
    error NotRegistrant(address registrant);
    /// @notice Reverts when the provided function name is empty.
    error EmptyFunctionName();
    /// @notice Reverts when attempting to register a selector that already exists.
    /// @param selector Conflicting selector already present in the registry.
    error TypeAlreadyRegistered(bytes4 selector);
    /// @notice Reverts when a tuple node declares zero children.
    error EmptyTuple();
    /// @notice Reverts when a non-tuple node declares tuple children.
    error UnexpectedTupleComponents();
    /// @notice Reverts when a sized ABI type uses an unsupported width or when an unsized type sets `size`.
    /// @param baseType Base type whose size was invalid.
    /// @param size Invalid width value.
    error InvalidTypeSize(BaseType baseType, uint16 size);
    /// @notice Reverts when the flattened type tree cannot be traversed consistently.
    error MalformedTypeTree();
    /// @notice Reverts when a nested tuple member is marked as indexed.
    error NestedIndexedComponent();
    /// @notice Reverts when more than three top-level parameters are marked indexed.
    /// @param indexedCount Number of indexed parameters encountered.
    error TooManyIndexedParameters(uint256 indexedCount);

    /// @notice Emitted when a new type is registered.
    /// @param registrant Account that controls future metadata updates for the selector.
    /// @param selector Four-byte selector derived from the canonical signature.
    /// @param version Monotonic version of the registry entry, starting at 1 on registration.
    /// @param canonicalSignature Canonical ABI signature used for selector derivation.
    /// @param declarationSignature Human-readable declaration form including names and top-level `indexed` markers.
    /// @param description Free-form description of the registered type.
    /// @param specURI URI pointing to an external specification or schema.
    event TypeRegistered(
        address indexed registrant,
        bytes4 indexed selector,
        uint16 version,
        string canonicalSignature,
        string declarationSignature,
        string description,
        string specURI
    );

    /// @notice Emitted when the mutable metadata of a registered type is updated.
    /// @param selector Four-byte selector of the updated registry entry.
    /// @param version Monotonic version after the update has been applied.
    /// @param description New descriptive text stored for the selector.
    /// @param specURI New URI pointing to the external specification or schema.
    event TypeUpdated(bytes4 indexed selector, uint16 version, string description, string specURI);

    /// @notice Registers a new type definition and returns its derived selector.
    /// @dev Reverts if another entry already exists for the derived selector.
    /// @param entry Structured type registration payload used to derive the stored signatures.
    /// @return selector Four-byte selector derived from the canonical signature.
    function register(TypeRegistrationParams calldata entry) external returns (bytes4 selector);

    /// @notice Updates the mutable metadata for an existing selector.
    /// @dev The canonical and declaration signatures remain immutable after registration.
    /// @param selector Selector of the entry to update.
    /// @param description New descriptive text for the entry.
    /// @param specURI New URI pointing to the type specification.
    function update(bytes4 selector, string calldata description, string calldata specURI) external;

    /// @notice Returns the registry entry stored for a selector.
    /// @param selector Selector of the entry to fetch.
    /// @return canonicalSignature Canonical ABI signature used for selector derivation.
    /// @return declarationSignature Human-readable declaration form including names and top-level `indexed` markers.
    /// @return description Descriptive text stored for the selector.
    /// @return specURI URI pointing to the external specification or schema.
    /// @return registrant Account authorized to update the mutable metadata.
    /// @return version Monotonic entry version.
    function getType(bytes4 selector)
        external
        view
        returns (
            string memory canonicalSignature,
            string memory declarationSignature,
            string memory description,
            string memory specURI,
            address registrant,
            uint16 version
        );
}
