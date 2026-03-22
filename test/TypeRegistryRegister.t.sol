// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SetupTest, ISelectorFixtures} from "./setup.t.sol";
import {ITypeRegistry} from "../src/interfaces/ITypeRegistry.sol";
import {BaseType, TypeComponent} from "../src/types/TypeComponent.sol";
import {TypeRegistrationParams} from "../src/types/TypeRegistrationParams.sol";

contract TypeRegistryRegisterTest is SetupTest {
    function test_registerMatchesActualSelectorForNoArgsSignature() public {
        bytes4 selector = registry.register(_noArgsParams());
        bytes memory payload = abi.encodeCall(ISelectorFixtures.noArgs, ());

        _assertSelectorMatchesCall(selector, ISelectorFixtures.noArgs.selector, payload, "noArgs()");
    }

    function test_registerMatchesActualSelectorForSimpleSignature() public {
        bytes4 selector = registry.register(_simpleParams("amount", "enabled", true));
        bytes memory payload = abi.encodeCall(ISelectorFixtures.simple, (uint256(7), true));

        _assertSelectorMatchesCall(selector, ISelectorFixtures.simple.selector, payload, "simple(uint256,bool)");
    }

    function test_registerEmitsTypeRegisteredForSimpleSignature() public {
        TypeRegistrationParams memory params = _simpleParams("amount", "enabled", true);

        vm.expectEmit(address(registry));
        emit ITypeRegistry.TypeRegistered(
            address(this),
            ISelectorFixtures.simple.selector,
            1,
            "simple(uint256,bool)",
            "simple(uint256 indexed amount,bool enabled)",
            params.description,
            params.specURI
        );

        bytes4 selector = registry.register(params);
        assertEq(selector, ISelectorFixtures.simple.selector);
    }

    function test_registerAllowsThreeIndexedTopLevelParameters() public {
        TypeComponent[] memory inputs = new TypeComponent[](3);
        inputs[0] = _component(BaseType.Address, 0, 0, _dimensions(), "owner", true);
        inputs[1] = _component(BaseType.Uint, 256, 0, _dimensions(), "amount", true);
        inputs[2] = _component(BaseType.Bool, 0, 0, _dimensions(), "enabled", true);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "tripleIndexed",
            inputs: inputs,
            description: "three indexed params",
            specURI: "ipfs://triple-indexed"
        });

        bytes4 selector = registry.register(params);
        bytes memory payload = abi.encodeCall(ISelectorFixtures.tripleIndexed, (address(0xCAFE), uint256(5), true));

        _assertSelectorMatchesCall(
            selector,
            ISelectorFixtures.tripleIndexed.selector,
            payload,
            "tripleIndexed(address,uint256,bool)"
        );
    }

    function test_registerMatchesActualSelectorForMixedSignature() public {
        bytes4 selector = registry.register(_mixedParams());
        bytes memory payload = abi.encodeCall(ISelectorFixtures.mixed, (hex"cafe", "topic", int128(-12)));

        _assertSelectorMatchesCall(selector, ISelectorFixtures.mixed.selector, payload, "mixed(bytes,string,int128)");
    }

    function test_registerMatchesActualSelectorForArraySignature() public {
        TypeComponent[] memory inputs = new TypeComponent[](3);
        inputs[0] = _component(BaseType.Address, 0, 0, _dimensions(), "owner", true);
        inputs[1] = _component(BaseType.Uint, 256, 0, _dimensions(0), "amounts", false);
        inputs[2] = _component(BaseType.BytesN, 32, 0, _dimensions(2), "hashes", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "arrays", inputs: inputs, description: "array registration", specURI: "ipfs://arrays"
        });

        bytes4 selector = registry.register(params);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;
        bytes32[2] memory hashes = [bytes32(uint256(11)), bytes32(uint256(22))];
        bytes memory payload = abi.encodeCall(ISelectorFixtures.arrays, (address(0xCAFE), amounts, hashes));

        _assertSelectorMatchesCall(
            selector, ISelectorFixtures.arrays.selector, payload, "arrays(address,uint256[],bytes32[2])"
        );
    }

    function test_registerMatchesActualSelectorForMultiDimensionalArraySignature() public {
        TypeComponent[] memory inputs = new TypeComponent[](2);
        inputs[0] = _component(BaseType.Uint, 256, 0, _dimensions(2, 0), "grid", false);
        inputs[1] = _component(BaseType.BytesN, 32, 0, _dimensions(0, 3), "proofs", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "matrix",
            inputs: inputs,
            description: "multi-dimensional array registration",
            specURI: "ipfs://matrix"
        });

        bytes4 selector = registry.register(params);

        uint256[2][] memory grid = new uint256[2][](2);
        grid[0] = [uint256(1), uint256(2)];
        grid[1] = [uint256(3), uint256(4)];

        bytes32[][3] memory proofs;
        proofs[0] = new bytes32[](1);
        proofs[0][0] = bytes32(uint256(10));
        proofs[1] = new bytes32[](2);
        proofs[1][0] = bytes32(uint256(20));
        proofs[1][1] = bytes32(uint256(21));
        proofs[2] = new bytes32[](0);

        bytes memory payload = abi.encodeCall(ISelectorFixtures.matrix, (grid, proofs));

        _assertSelectorMatchesCall(
            selector,
            ISelectorFixtures.matrix.selector,
            payload,
            "matrix(uint256[2][],bytes32[][3])"
        );
    }

    function test_registerMatchesActualSelectorForNestedTupleSignature() public {
        bytes4 selector = registry.register(_metadataParams());

        ISelectorFixtures.Inner[] memory items = new ISelectorFixtures.Inner[](1);
        items[0] = ISelectorFixtures.Inner({amount: 42, salt: bytes32(uint256(9))});

        ISelectorFixtures.Outer[] memory entries = new ISelectorFixtures.Outer[](1);
        entries[0] = ISelectorFixtures.Outer({label: "alpha", items: items});

        bytes32[2] memory hashes = [bytes32(uint256(100)), bytes32(uint256(200))];
        bytes memory payload = abi.encodeCall(ISelectorFixtures.metadata, (address(0xBEEF), entries, hashes));

        _assertSelectorMatchesCall(
            selector,
            ISelectorFixtures.metadata.selector,
            payload,
            "metadata(address,(string,(uint256,bytes32)[])[],bytes32[2])"
        );
    }

    function testRevert_registerRejectsDuplicateSelectorWhenOnlyNamesOrIndexedDiffer() public {
        bytes4 selector = registry.register(_simpleParams("amount", "enabled", true));

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.TypeAlreadyRegistered.selector, selector));
        registry.register(_simpleParams("value", "flag", false));
    }

    function testRevert_registerRejectsEmptyFunctionName() public {
        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "", inputs: new TypeComponent[](0), description: "empty name", specURI: "ipfs://empty-name"
        });

        vm.expectRevert(ITypeRegistry.EmptyFunctionName.selector);
        registry.register(params);
    }

    function testRevert_registerRejectsTupleWithoutMembers() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Tuple, 0, 0, _dimensions(), "brokenTuple", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "invalid", inputs: inputs, description: "invalid tuple", specURI: "ipfs://invalid"
        });

        vm.expectRevert(ITypeRegistry.EmptyTuple.selector);
        registry.register(params);
    }

    function testRevert_registerRejectsMalformedFlattenedTree() public {
        TypeComponent[] memory inputs = new TypeComponent[](2);
        inputs[0] = _component(BaseType.Tuple, 0, 2, _dimensions(), "root", false);
        inputs[1] = _component(BaseType.Bool, 0, 0, _dimensions(), "flag", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "broken", inputs: inputs, description: "malformed tree", specURI: "ipfs://broken"
        });

        vm.expectRevert(ITypeRegistry.MalformedTypeTree.selector);
        registry.register(params);
    }

    function testRevert_registerRejectsNestedIndexedComponent() public {
        TypeComponent[] memory inputs = new TypeComponent[](2);
        inputs[0] = _component(BaseType.Tuple, 0, 1, _dimensions(), "entry", false);
        inputs[1] = _component(BaseType.Uint, 256, 0, _dimensions(), "amount", true);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "invalidNestedIndexed",
            inputs: inputs,
            description: "nested indexed component",
            specURI: "ipfs://nested-indexed"
        });

        vm.expectRevert(ITypeRegistry.NestedIndexedComponent.selector);
        registry.register(params);
    }

    function testRevert_registerRejectsMoreThanThreeIndexedTopLevelParameters() public {
        TypeComponent[] memory inputs = new TypeComponent[](4);
        inputs[0] = _component(BaseType.Address, 0, 0, _dimensions(), "a", true);
        inputs[1] = _component(BaseType.Bool, 0, 0, _dimensions(), "b", true);
        inputs[2] = _component(BaseType.Uint, 256, 0, _dimensions(), "c", true);
        inputs[3] = _component(BaseType.BytesN, 32, 0, _dimensions(), "d", true);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "tooManyIndexed",
            inputs: inputs,
            description: "too many indexed params",
            specURI: "ipfs://too-many-indexed"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.TooManyIndexedParameters.selector, 4));
        registry.register(params);
    }

    function testRevert_registerRejectsNonTupleWithChildren() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Address, 0, 1, _dimensions(), "owner", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badChildren", inputs: inputs, description: "bad children", specURI: "ipfs://bad-children"
        });

        vm.expectRevert(ITypeRegistry.UnexpectedTupleComponents.selector);
        registry.register(params);
    }

    function testRevert_registerRejectsTupleWithExplicitSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](2);
        inputs[0] = _component(BaseType.Tuple, 1, 1, _dimensions(), "entry", false);
        inputs[1] = _component(BaseType.Bool, 0, 0, _dimensions(), "flag", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badTupleSize", inputs: inputs, description: "bad tuple size", specURI: "ipfs://bad-tuple-size"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.Tuple, uint16(1)));
        registry.register(params);
    }

    function testRevert_registerRejectsUnsizedTypeWithExplicitSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Address, 20, 0, _dimensions(), "owner", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badAddress", inputs: inputs, description: "bad address", specURI: "ipfs://bad-address"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.Address, uint16(20)));
        registry.register(params);
    }

    function testRevert_registerRejectsBoolWithExplicitSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Bool, 8, 0, _dimensions(), "enabled", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badBool", inputs: inputs, description: "bad bool", specURI: "ipfs://bad-bool"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.Bool, uint16(8)));
        registry.register(params);
    }

    function testRevert_registerRejectsStringWithExplicitSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.String, 32, 0, _dimensions(), "label", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badString", inputs: inputs, description: "bad string", specURI: "ipfs://bad-string"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.String, uint16(32)));
        registry.register(params);
    }

    function testRevert_registerRejectsDynamicBytesWithExplicitSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Bytes, 32, 0, _dimensions(), "blob", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badBytes", inputs: inputs, description: "bad bytes", specURI: "ipfs://bad-bytes"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.Bytes, uint16(32)));
        registry.register(params);
    }

    function testRevert_registerRejectsInvalidBytesNSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.BytesN, 33, 0, _dimensions(), "hash", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badBytesN", inputs: inputs, description: "bad bytesN", specURI: "ipfs://bad-bytesn"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.BytesN, uint16(33)));
        registry.register(params);
    }

    function testRevert_registerRejectsInvalidWordSize() public {
        TypeComponent[] memory inputs = new TypeComponent[](1);
        inputs[0] = _component(BaseType.Int, 7, 0, _dimensions(), "delta", false);

        TypeRegistrationParams memory params = TypeRegistrationParams({
            functionName: "badInt", inputs: inputs, description: "bad int", specURI: "ipfs://bad-int"
        });

        vm.expectRevert(abi.encodeWithSelector(ITypeRegistry.InvalidTypeSize.selector, BaseType.Int, uint16(7)));
        registry.register(params);
    }
}
