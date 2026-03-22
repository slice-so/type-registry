// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BaseType, TypeComponent} from "./types/TypeComponent.sol";
import {TypeRegistrationParams} from "./types/TypeRegistrationParams.sol";
import {TypeEntry} from "./types/TypeEntry.sol";
import {ITypeRegistry} from "./interfaces/ITypeRegistry.sol";

/// @title Type Registry
/// @notice Registers structured ABI type descriptions and stores both canonical and declaration-style signatures.
contract TypeRegistry is ITypeRegistry {
    using Strings for uint256;

    mapping(bytes4 => TypeEntry) private typeEntries;

    /// @inheritdoc ITypeRegistry
    function register(TypeRegistrationParams calldata entry) external returns (bytes4 selector) {
        (string memory canonicalSignature, string memory declarationSignature) =
            _deriveSignatures(entry.functionName, entry.inputs);
        selector = bytes4(keccak256(bytes(canonicalSignature)));

        if (typeEntries[selector].registrant != address(0)) {
            revert TypeAlreadyRegistered(selector);
        }

        typeEntries[selector] = TypeEntry({
            registrant: msg.sender,
            version: 1,
            canonicalSignature: canonicalSignature,
            declarationSignature: declarationSignature,
            description: entry.description,
            specURI: entry.specURI
        });

        emit TypeRegistered(
            msg.sender, selector, 1, canonicalSignature, declarationSignature, entry.description, entry.specURI
        );
    }

    /// @inheritdoc ITypeRegistry
    function update(bytes4 selector, string calldata description, string calldata specURI) external {
        TypeEntry storage typeEntry = typeEntries[selector];
        address registrant = typeEntry.registrant;

        if (registrant != msg.sender) {
            revert NotRegistrant(registrant);
        }

        typeEntry.description = description;
        typeEntry.specURI = specURI;

        uint16 version;
        unchecked {
            version = ++typeEntry.version;
        }

        emit TypeUpdated(selector, version, description, specURI);
    }

    /// @inheritdoc ITypeRegistry
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
        )
    {
        TypeEntry memory typeEntry = typeEntries[selector];
        return (
            typeEntry.canonicalSignature,
            typeEntry.declarationSignature,
            typeEntry.description,
            typeEntry.specURI,
            typeEntry.registrant,
            typeEntry.version
        );
    }

    // ==========================
    // =======  Internal  =======
    // ==========================

    /// @notice Reconstructs the canonical and declaration signatures from the flattened type tree.
    /// @dev Enforces top-level-only `indexed` markers and the maximum of three indexed parameters.
    /// @param functionName Function or event-like name that prefixes the signature.
    /// @param inputs Flattened pre-order list of top-level parameters and tuple descendants.
    /// @return canonicalSignature ABI-canonical signature used for selector derivation.
    /// @return declarationSignature Display-oriented signature including names and top-level `indexed`.
    function _deriveSignatures(string calldata functionName, TypeComponent[] calldata inputs)
        internal
        pure
        returns (string memory canonicalSignature, string memory declarationSignature)
    {
        if (bytes(functionName).length == 0) {
            revert EmptyFunctionName();
        }

        bytes memory canonicalEncoded = abi.encodePacked(functionName, "(");
        bytes memory declarationEncoded = abi.encodePacked(functionName, "(");
        uint256 cursor = 0;
        uint256 indexedCount = 0;

        while (cursor < inputs.length) {
            if (cursor != 0) {
                canonicalEncoded = abi.encodePacked(canonicalEncoded, ",");
                declarationEncoded = abi.encodePacked(declarationEncoded, ",");
            }

            TypeComponent calldata topLevelComponent = inputs[cursor];

            if (topLevelComponent.isIndexed) {
                unchecked {
                    ++indexedCount;
                }

                if (indexedCount > 3) {
                    revert TooManyIndexedParameters(indexedCount);
                }
            }

            (bytes memory canonicalComponent, bytes memory declarationComponent, uint256 nextCursor) =
                _encodeComponent(inputs, cursor, 0);
            canonicalEncoded = abi.encodePacked(canonicalEncoded, canonicalComponent);
            declarationEncoded = abi.encodePacked(declarationEncoded, declarationComponent);
            cursor = nextCursor;
        }

        return (string(abi.encodePacked(canonicalEncoded, ")")), string(abi.encodePacked(declarationEncoded, ")")));
    }

    /// @notice Encodes one component subtree and returns the next unread index in the flattened tree.
    /// @param components Flattened pre-order component list.
    /// @param index Index of the component to encode.
    /// @param depth Tuple nesting depth of the component, where zero means top-level.
    /// @return canonicalEncoding Canonical ABI encoding fragment for the component.
    /// @return declarationEncoding Declaration-style encoding fragment for the component.
    /// @return nextIndex First unread component index after the encoded subtree.
    function _encodeComponent(TypeComponent[] calldata components, uint256 index, uint256 depth)
        internal
        pure
        returns (bytes memory canonicalEncoding, bytes memory declarationEncoding, uint256 nextIndex)
    {
        TypeComponent calldata component = components[index];

        if (depth != 0 && component.isIndexed) {
            revert NestedIndexedComponent();
        }

        (canonicalEncoding, declarationEncoding, nextIndex) = _encodeBaseType(components, component, index, depth);

        for (uint256 i = 0; i < component.arrayDimensions.length; ++i) {
            uint256 dimension = component.arrayDimensions[i];

            if (dimension == 0) {
                canonicalEncoding = abi.encodePacked(canonicalEncoding, "[]");
                declarationEncoding = abi.encodePacked(declarationEncoding, "[]");
            } else {
                string memory dimensionString = dimension.toString();
                canonicalEncoding = abi.encodePacked(canonicalEncoding, "[", dimensionString, "]");
                declarationEncoding = abi.encodePacked(declarationEncoding, "[", dimensionString, "]");
            }
        }

        if (depth == 0 && component.isIndexed) {
            declarationEncoding = abi.encodePacked(declarationEncoding, " indexed");
        }

        if (bytes(component.name).length != 0) {
            declarationEncoding = abi.encodePacked(declarationEncoding, " ", component.name);
        }
    }

    /// @notice Encodes a component's base type, delegating to tuple traversal when necessary.
    /// @param components Flattened pre-order component list.
    /// @param component Component being encoded.
    /// @param index Index of `component` within `components`.
    /// @param depth Tuple nesting depth of the component.
    /// @return canonicalEncoding Canonical ABI fragment for the component's base type.
    /// @return declarationEncoding Declaration-style fragment for the component's base type.
    /// @return nextIndex First unread index after the component subtree.
    function _encodeBaseType(
        TypeComponent[] calldata components,
        TypeComponent calldata component,
        uint256 index,
        uint256 depth
    ) internal pure returns (bytes memory canonicalEncoding, bytes memory declarationEncoding, uint256 nextIndex) {
        BaseType baseType = component.baseType;

        if (baseType == BaseType.Tuple) {
            if (component.size != 0) {
                revert InvalidTypeSize(baseType, component.size);
            }

            return _encodeTuple(components, index, depth);
        }

        if (component.childCount != 0) {
            revert UnexpectedTupleComponents();
        }

        nextIndex = index + 1;

        if (baseType == BaseType.Address) {
            if (component.size != 0) {
                revert InvalidTypeSize(baseType, component.size);
            }

            return ("address", "address", nextIndex);
        }

        if (baseType == BaseType.Bool) {
            if (component.size != 0) {
                revert InvalidTypeSize(baseType, component.size);
            }

            return ("bool", "bool", nextIndex);
        }

        if (baseType == BaseType.String) {
            if (component.size != 0) {
                revert InvalidTypeSize(baseType, component.size);
            }

            return ("string", "string", nextIndex);
        }

        if (baseType == BaseType.Bytes) {
            if (component.size != 0) {
                revert InvalidTypeSize(baseType, component.size);
            }

            return ("bytes", "bytes", nextIndex);
        }

        if (baseType == BaseType.BytesN) {
            return _encodeSizedType(baseType, "bytes", component.size, nextIndex);
        }

        if (baseType == BaseType.Uint) {
            return _encodeSizedType(baseType, "uint", component.size, nextIndex);
        }

        // All supported enum variants have been handled above, so the only remaining valid base type is `Int`.
        return _encodeSizedType(baseType, "int", component.size, nextIndex);
    }

    /// @notice Encodes a tuple node and its descendants from the flattened pre-order representation.
    /// @param components Flattened pre-order component list.
    /// @param index Index of the tuple node.
    /// @param depth Current tuple nesting depth.
    /// @return canonicalEncoding Canonical tuple fragment.
    /// @return declarationEncoding Declaration-style tuple fragment.
    /// @return nextIndex First unread index after the tuple subtree.
    function _encodeTuple(TypeComponent[] calldata components, uint256 index, uint256 depth)
        internal
        pure
        returns (bytes memory canonicalEncoding, bytes memory declarationEncoding, uint256 nextIndex)
    {
        TypeComponent calldata component = components[index];

        if (component.childCount == 0) {
            revert EmptyTuple();
        }

        canonicalEncoding = "(";
        declarationEncoding = "(";
        nextIndex = index + 1;

        for (uint256 i = 0; i < component.childCount; ++i) {
            if (i != 0) {
                canonicalEncoding = abi.encodePacked(canonicalEncoding, ",");
                declarationEncoding = abi.encodePacked(declarationEncoding, ",");
            }

            if (nextIndex >= components.length) {
                revert MalformedTypeTree();
            }

            (bytes memory childCanonicalEncoding, bytes memory childDeclarationEncoding, uint256 followingIndex) =
                _encodeComponent(components, nextIndex, depth + 1);
            canonicalEncoding = abi.encodePacked(canonicalEncoding, childCanonicalEncoding);
            declarationEncoding = abi.encodePacked(declarationEncoding, childDeclarationEncoding);
            nextIndex = followingIndex;
        }

        canonicalEncoding = abi.encodePacked(canonicalEncoding, ")");
        declarationEncoding = abi.encodePacked(declarationEncoding, ")");
    }

    /// @notice Encodes a fixed-width scalar ABI type.
    /// @param baseType Base type being encoded.
    /// @param prefix Type name prefix without the width suffix.
    /// @param size Width value appended to `prefix`.
    /// @param nextIndex First unread index after the scalar component.
    /// @return canonicalEncoding Canonical ABI fragment for the scalar type.
    /// @return declarationEncoding Declaration-style fragment for the scalar type.
    /// @return followingIndex Unchanged passthrough of `nextIndex`.
    function _encodeSizedType(BaseType baseType, bytes memory prefix, uint16 size, uint256 nextIndex)
        internal
        pure
        returns (bytes memory canonicalEncoding, bytes memory declarationEncoding, uint256 followingIndex)
    {
        if (baseType == BaseType.BytesN) {
            _validateBytesNSize(baseType, size);
        } else {
            _validateWordSize(baseType, size);
        }

        canonicalEncoding = abi.encodePacked(prefix, uint256(size).toString());
        declarationEncoding = canonicalEncoding;
        followingIndex = nextIndex;
    }

    /// @notice Validates the width of a fixed-size `bytesN` type.
    /// @param baseType Base type being validated.
    /// @param size Declared byte width.
    function _validateBytesNSize(BaseType baseType, uint16 size) internal pure {
        if (size == 0 || size > 32) {
            revert InvalidTypeSize(baseType, size);
        }
    }

    /// @notice Validates the width of an `intN` or `uintN` type.
    /// @param baseType Base type being validated.
    /// @param size Declared bit width.
    function _validateWordSize(BaseType baseType, uint16 size) internal pure {
        if (size < 8 || size > 256 || size % 8 != 0) {
            revert InvalidTypeSize(baseType, size);
        }
    }
}
