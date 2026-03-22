// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TypeComponent} from "./TypeComponent.sol";

/// @notice Input payload used to register a selector-derived type entry.
/// @param functionName Name of the function or event-like declaration being reconstructed.
/// @param inputs Flattened pre-order list of top-level parameters and tuple descendants.
/// @param description Free-form description of the registered type.
/// @param specURI URI pointing to a specification, schema, or other external reference.
struct TypeRegistrationParams {
    string functionName;
    TypeComponent[] inputs;
    string description;
    string specURI;
}
