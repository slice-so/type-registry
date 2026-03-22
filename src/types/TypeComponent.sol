// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Supported ABI base types for a registered parameter component.
/// @dev `BytesN`, `Uint`, and `Int` use `TypeComponent.size` to capture their explicit bit or byte width.
enum BaseType {
    Address,
    Bool,
    String,
    Bytes,
    BytesN,
    Uint,
    Int,
    Tuple
}

/// @notice Describes one node in a flattened pre-order ABI type tree.
/// @dev
/// A top-level parameter is represented by one root component in the `inputs` array.
/// Tuple children immediately follow their tuple parent in pre-order, and `childCount`
/// specifies how many direct children belong to that tuple node.
///
/// `arrayDimensions` stores the array suffixes applied after the base type:
/// - `[]` is encoded as `0`
/// - `[N]` is encoded as `N`
///
/// Examples:
/// - `uint256` => `arrayDimensions = []`
/// - `uint256[]` => `arrayDimensions = [0]`
/// - `bytes32[2]` => `arrayDimensions = [2]`
/// - `(string,uint256[])[]` => tuple node with `arrayDimensions = [0]`
/// @param baseType ABI base type of this component.
/// @param size Explicit width for `BytesN`, `Uint`, or `Int`; must be zero for all other base types.
/// @param childCount Number of direct child components for tuple nodes; must be zero for non-tuple nodes.
/// @param arrayDimensions Ordered array suffixes applied after the base type or tuple.
/// @param name Optional parameter or tuple-member name included only in the declaration signature.
/// @param isIndexed Whether the top-level parameter is declared `indexed`; invalid for nested tuple members.
struct TypeComponent {
    BaseType baseType;
    uint16 size;
    uint256 childCount;
    uint256[] arrayDimensions;
    string name;
    bool isIndexed;
}
