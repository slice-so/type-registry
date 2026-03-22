// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SetupTest} from "./setup.t.sol";

contract TypeRegistryGetTypeTest is SetupTest {
    function test_getTypeReturnsZeroValuesForUnknownSelector() public view {
        (
            string memory canonicalSignature,
            string memory declarationSignature,
            string memory description,
            string memory specURI,
            address registrant,
            uint16 version
        ) = registry.getType(bytes4(0x12345678));

        assertEq(canonicalSignature, "");
        assertEq(declarationSignature, "");
        assertEq(description, "");
        assertEq(specURI, "");
        assertEq(registrant, address(0));
        assertEq(version, 0);
    }

    function test_getTypeReturnsRegisteredNoArgsEntry() public {
        bytes4 selector = registry.register(_noArgsParams());

        (
            string memory canonicalSignature,
            string memory declarationSignature,
            string memory description,
            string memory specURI,
            address registrant,
            uint16 version
        ) = registry.getType(selector);

        assertEq(canonicalSignature, "noArgs()");
        assertEq(declarationSignature, "noArgs()");
        assertEq(description, "no args registration");
        assertEq(specURI, "ipfs://no-args");
        assertEq(registrant, address(this));
        assertEq(version, 1);
    }

    function test_getTypeReturnsRegisteredMetadataEntry() public {
        bytes4 selector = registry.register(_metadataParams());

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
        assertEq(description, "nested tuple registration");
        assertEq(specURI, "ipfs://spec");
        assertEq(registrant, address(this));
        assertEq(version, 1);
    }

    function test_getTypeOmitsUnnamedParametersFromDeclarationSignature() public {
        bytes4 selector = registry.register(_mixedParams());

        (
            string memory canonicalSignature,
            string memory declarationSignature,
            string memory description,
            string memory specURI,
            address registrant,
            uint16 version
        ) = registry.getType(selector);

        assertEq(canonicalSignature, "mixed(bytes,string,int128)");
        assertEq(declarationSignature, "mixed(bytes,string label,int128)");
        assertEq(description, "mixed registration");
        assertEq(specURI, "ipfs://mixed");
        assertEq(registrant, address(this));
        assertEq(version, 1);
    }
}
