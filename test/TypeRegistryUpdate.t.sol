// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SetupTest} from "./setup.t.sol";
import {ITypeRegistry} from "../src/interfaces/ITypeRegistry.sol";

contract TypeRegistryUpdateTest is SetupTest {
    function test_updateEmitsTypeUpdatedWithIncrementedVersion() public {
        bytes4 selector = registry.register(_metadataParams());

        vm.expectEmit(address(registry));
        emit ITypeRegistry.TypeUpdated(selector, 2, "updated metadata", "ipfs://updated-metadata");

        registry.update(selector, "updated metadata", "ipfs://updated-metadata");
    }

    function test_updateIncrementsVersionAndPreservesSignatures() public {
        bytes4 selector = registry.register(_metadataParams());

        registry.update(selector, "first update", "ipfs://first");
        registry.update(selector, "second update", "ipfs://second");

        (
            string memory canonicalSignature,
            string memory declarationSignature,
            string memory description,
            string memory specURI,
            address registrant,
            uint16 version
        ) = registry.getType(selector);

        assertEq(canonicalSignature, "metadata(address,(string,(uint256,bytes32)[])[],bytes32[2])");
        assertEq(
            declarationSignature,
            "metadata(address indexed owner,(string label,(uint256 amount,bytes32 salt)[] items)[] indexed entries,bytes32[2] hashes)"
        );
        assertEq(description, "second update");
        assertEq(specURI, "ipfs://second");
        assertEq(registrant, address(this));
        assertEq(version, 3);
    }

    function testRevert_updateOnlyAllowsRegistrant() public {
        bytes4 selector = registry.register(_metadataParams());

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.NotRegistrant.selector, address(this)));
        registry.update(selector, "unauthorized", "ipfs://unauthorized");
    }

    function testRevert_updateUnknownSelectorHasZeroRegistrant() public {
        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.NotRegistrant.selector, address(0)));
        registry.update(bytes4(0x99999999), "missing", "ipfs://missing");
    }
}
