// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {TypeRegistry} from "../src/TypeRegistry.sol";
import {BaseType, TypeComponent} from "../src/types/TypeComponent.sol";
import {TypeRegistrationParams} from "../src/types/TypeRegistrationParams.sol";

contract SetupTest is Test {
    SelectorFixtures internal fixtures;
    TypeRegistry internal registry;

    function setUp() public virtual {
        fixtures = new SelectorFixtures();
        registry = new TypeRegistry();
    }

    function _metadataParams() internal pure returns (TypeRegistrationParams memory params) {
        TypeComponent[] memory inputs = new TypeComponent[](7);
        inputs[0] = _component(BaseType.Address, 0, 0, _dimensions(), "owner", true);
        inputs[1] = _component(BaseType.Tuple, 0, 2, _dimensions(0), "entries", true);
        inputs[2] = _component(BaseType.String, 0, 0, _dimensions(), "label", false);
        inputs[3] = _component(BaseType.Tuple, 0, 2, _dimensions(0), "items", false);
        inputs[4] = _component(BaseType.Uint, 256, 0, _dimensions(), "amount", false);
        inputs[5] = _component(BaseType.BytesN, 32, 0, _dimensions(), "salt", false);
        inputs[6] = _component(BaseType.BytesN, 32, 0, _dimensions(2), "hashes", false);

        params = TypeRegistrationParams({
            functionName: "metadata", inputs: inputs, description: "nested tuple registration", specURI: "ipfs://spec"
        });
    }

    function _simpleParams(string memory firstName, string memory secondName, bool firstIndexed)
        internal
        pure
        returns (TypeRegistrationParams memory params)
    {
        TypeComponent[] memory inputs = new TypeComponent[](2);
        inputs[0] = _component(BaseType.Uint, 256, 0, _dimensions(), firstName, firstIndexed);
        inputs[1] = _component(BaseType.Bool, 0, 0, _dimensions(), secondName, false);

        params = TypeRegistrationParams({
            functionName: "simple", inputs: inputs, description: "simple registration", specURI: "ipfs://simple"
        });
    }

    function _noArgsParams() internal pure returns (TypeRegistrationParams memory params) {
        params = TypeRegistrationParams({
            functionName: "noArgs", inputs: new TypeComponent[](0), description: "no args registration", specURI: "ipfs://no-args"
        });
    }

    function _mixedParams() internal pure returns (TypeRegistrationParams memory params) {
        TypeComponent[] memory inputs = new TypeComponent[](3);
        inputs[0] = _component(BaseType.Bytes, 0, 0, _dimensions(), "", false);
        inputs[1] = _component(BaseType.String, 0, 0, _dimensions(), "label", false);
        inputs[2] = _component(BaseType.Int, 128, 0, _dimensions(), "", false);

        params = TypeRegistrationParams({
            functionName: "mixed", inputs: inputs, description: "mixed registration", specURI: "ipfs://mixed"
        });
    }

    function _assertSelectorMatchesCall(
        bytes4 selector,
        bytes4 expectedSelector,
        bytes memory payload,
        string memory canonicalSignature
    ) internal {
        assertEq(selector, expectedSelector);
        assertEq(selector, bytes4(keccak256(bytes(canonicalSignature))));
        assertEq(_selectorFromPayload(payload), selector);

        (bool success,) = address(fixtures).call(payload);
        assertTrue(success);
    }

    function _selectorFromPayload(bytes memory payload) internal pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(payload, 32))
        }
    }

    function _component(
        BaseType baseType,
        uint16 size,
        uint256 childCount,
        uint256[] memory arrayDimensions,
        string memory name,
        bool isIndexed
    ) internal pure returns (TypeComponent memory component) {
        component = TypeComponent({
            baseType: baseType,
            size: size,
            childCount: childCount,
            arrayDimensions: arrayDimensions,
            name: name,
            isIndexed: isIndexed
        });
    }

    function _dimensions() internal pure returns (uint256[] memory dimensions) {
        dimensions = new uint256[](0);
    }

    function _dimensions(uint256 first) internal pure returns (uint256[] memory dimensions) {
        dimensions = new uint256[](1);
        dimensions[0] = first;
    }

    function _dimensions(uint256 first, uint256 second) internal pure returns (uint256[] memory dimensions) {
        dimensions = new uint256[](2);
        dimensions[0] = first;
        dimensions[1] = second;
    }
}

interface ISelectorFixtures {
    struct Inner {
        uint256 amount;
        bytes32 salt;
    }

    struct Outer {
        string label;
        Inner[] items;
    }

    function noArgs() external;
    function simple(uint256 amount, bool enabled) external;
    function tripleIndexed(address owner, uint256 amount, bool enabled) external;
    function mixed(bytes calldata data, string calldata label, int128 delta) external;
    function arrays(address owner, uint256[] calldata amounts, bytes32[2] calldata hashes) external;
    function matrix(uint256[2][] calldata grid, bytes32[][3] calldata proofs) external;
    function metadata(address owner, Outer[] calldata entries, bytes32[2] calldata hashes) external;
}

contract SelectorFixtures is ISelectorFixtures {
    function noArgs() external {}
    function simple(uint256, bool) external {}
    function tripleIndexed(address, uint256, bool) external {}
    function mixed(bytes calldata, string calldata, int128) external {}
    function arrays(address, uint256[] calldata, bytes32[2] calldata) external {}
    function matrix(uint256[2][] calldata, bytes32[][3] calldata) external {}
    function metadata(address, Outer[] calldata, bytes32[2] calldata) external {}
}
