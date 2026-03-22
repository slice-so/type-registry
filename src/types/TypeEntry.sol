// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Stored registry entry keyed by selector.
/// @param registrant Account authorized to update the entry's mutable metadata.
/// @param version Monotonic entry version, starting at 1 on registration.
/// @param canonicalSignature Canonical ABI signature used to derive the selector.
/// @param declarationSignature Human-readable declaration form including names and top-level `indexed` markers.
/// @param description Free-form description of the registered type.
/// @param specURI URI pointing to a specification, schema, or external reference.
struct TypeEntry {
    address registrant;
    uint16 version;
    string canonicalSignature;
    string declarationSignature;
    string description;
    string specURI;
}
