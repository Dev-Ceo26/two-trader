// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GuardianRegistry} from "../../contracts/governance/GuardianRegistry.sol";
import {DecisionRegistry} from "../../contracts/decisions/DecisionRegistry.sol";
import {ImperiumMessenger} from "../../contracts/bridge/ImperiumMessenger.sol";
import {ImperiumBridgeRoot} from "../../contracts/bridge/ImperiumBridgeRoot.sol";
import {DecisionLib} from "../../contracts/decisions/DecisionLib.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DecisionCanonTest is Test {
    GuardianRegistry internal registry;
    DecisionRegistry internal decisionRegistry;
    ImperiumMessenger internal messenger;
    ImperiumBridgeRoot internal bridgeRoot;

    address internal deployer = address(0xA11CE);

    // Private key note — da cui deriviamo gli address dei guardian
    uint256 internal pk1 = 0xA11CE1000000000000000000000000000000000000000000000000000000001;
    uint256 internal pk2 = 0xA11CE1000000000000000000000000000000000000000000000000000000002;
    uint256 internal pk3 = 0xA11CE1000000000000000000000000000000000000000000000000000000003;
    uint256 internal pk4 = 0xA11CE1000000000000000000000000000000000000000000000000000000004;
    uint256 internal pk5 = 0xA11CE1000000000000000000000000000000000000000000000000000000005;

    address internal g1;
    address internal g2;
    address internal g3;
    address internal g4;
    address internal g5;

    uint256 internal constant MIN_STAKE = 1 ether;
    uint256 internal constant COOLDOWN = 1 days;
    uint256 internal constant THRESHOLD = 3;
    uint256 internal constant L2_CHAIN_ID = 9818;

    function setUp() public {
        g1 = vm.addr(pk1);
        g2 = vm.addr(pk2);
        g3 = vm.addr(pk3);
        g4 = vm.addr(pk4);
        g5 = vm.addr(pk5);

        vm.deal(deployer, 100 ether);
        vm.deal(g1, 10 ether);
        vm.deal(g2, 10 ether);
        vm.deal(g3, 10 ether);
        vm.deal(g4, 10 ether);
        vm.deal(g5, 10 ether);

        // 1. GuardianRegistry
        GuardianRegistry regImpl = new GuardianRegistry();
        bytes memory regInit = abi.encodeWithSelector(
            GuardianRegistry.initialize.selector,
            deployer, MIN_STAKE, COOLDOWN
        );
        registry = GuardianRegistry(address(new ERC1967Proxy(address(regImpl), regInit)));

        // 2. DecisionRegistry
        DecisionRegistry dregImpl = new DecisionRegistry();
        bytes memory dregInit = abi.encodeWithSelector(
            DecisionRegistry.initialize.selector,
            deployer
        );
        decisionRegistry = DecisionRegistry(address(new ERC1967Proxy(address(dregImpl), dregInit)));

        // 3. ImperiumMessenger
        ImperiumMessenger msgImpl = new ImperiumMessenger();
        bytes memory msgInit = abi.encodeWithSelector(
            ImperiumMessenger.initialize.selector,
            address(registry), address(decisionRegistry), THRESHOLD
        );
        messenger = ImperiumMessenger(address(new ERC1967Proxy(address(msgImpl), msgInit)));

        // 4. ImperiumBridgeRoot
        ImperiumBridgeRoot rootImpl = new ImperiumBridgeRoot();
        bytes memory rootInit = abi.encodeWithSelector(
            ImperiumBridgeRoot.initialize.selector,
            address(messenger), L2_CHAIN_ID, deployer
        );
        bridgeRoot = ImperiumBridgeRoot(address(new ERC1967Proxy(address(rootImpl), rootInit)));

        // 5. Registra 5 guardian
        _registerGuardian(g1);
        _registerGuardian(g2);
        _registerGuardian(g3);
        _registerGuardian(g4);
        _registerGuardian(g5);
    }

    function _registerGuardian(address g) internal {
        vm.prank(g);
        registry.registerGuardian{value: MIN_STAKE}(bytes32(uint256(uint160(g))));
    }

    function _buildDecision(uint256 nonce) internal view returns (DecisionLib.Decision memory d) {
        d = DecisionLib.Decision({
            kind:          DecisionLib.KIND_DEPOSIT,
            actor:         g1,
            token:         address(0xBEEF),
            recipient:     g2,
            amount:        1 ether,
            nonce:         nonce,
            srcChainId:    block.chainid,
            dstChainId:    L2_CHAIN_ID,
            deadline:      uint64(block.timestamp + 1 hours),
            rationaleHash: keccak256("test")
        });
    }

    function _sign(DecisionLib.Decision memory d, uint256 pk) internal pure returns (bytes memory) {
        bytes32 id = DecisionLib.hash(d);
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", id));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    // ============ INVARIANTE 1: decisione non registrata ============
    function test_UnrecordedDecisionFails() public view {
        DecisionLib.Decision memory d = _buildDecision(1);
        bytes[] memory sigs = new bytes[](0);
        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "unrecorded decision must fail");
    }

    // ============ INVARIANTE 2: decisione vetata ============
    function test_VetoedDecisionFails() public {
        DecisionLib.Decision memory d = _buildDecision(2);
        bytes32 id = decisionRegistry.record(d);
        assertTrue(decisionRegistry.isRecorded(id));
        assertFalse(decisionRegistry.isVetoed(id));

        vm.prank(deployer);
        decisionRegistry.veto(id, "test veto");

        assertTrue(decisionRegistry.isVetoed(id));

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(d, pk1);
        sigs[1] = _sign(d, pk2);
        sigs[2] = _sign(d, pk3);

        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "vetoed decision must fail even with 3 valid signatures");
    }

    // ============ INVARIANTE 3: decisione scaduta ============
    function test_DeadlineExpiredFails() public {
        DecisionLib.Decision memory d = _buildDecision(3);
        decisionRegistry.record(d);

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(d, pk1);
        sigs[1] = _sign(d, pk2);
        sigs[2] = _sign(d, pk3);

        // Avanza il tempo oltre la deadline della decisione
        vm.warp(d.deadline + 1);

        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "expired decision must fail even with 3 valid signatures");
    }

    // ============ INVARIANTE 4: sotto threshold ============
    function test_BelowThresholdFails() public {
        DecisionLib.Decision memory d = _buildDecision(4);
        decisionRegistry.record(d);

        // Solo 2 firme, threshold 3
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(d, pk1);
        sigs[1] = _sign(d, pk2);

        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "2 signatures below threshold 3 must fail");
    }

    // ============ INVARIANTE 5: record duplicato ============
    function test_CannotRecordTwice() public {
        DecisionLib.Decision memory d = _buildDecision(5);
        decisionRegistry.record(d);

        vm.expectRevert("already recorded");
        decisionRegistry.record(d);
    }

    // ============ INVARIANTE 6: validate rifiuta decisione malformata ============
    function test_InvalidDecisionRejected() public {
        DecisionLib.Decision memory d = _buildDecision(6);
        d.actor = address(0);

        vm.expectRevert("invalid decision");
        decisionRegistry.record(d);
    }

    // ============ INVARIANTE 7: HAPPY PATH con 3 firme valide ============
    function test_HappyPathThreeValidSignatures() public {
        DecisionLib.Decision memory d = _buildDecision(7);
        decisionRegistry.record(d);

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(d, pk1);
        sigs[1] = _sign(d, pk2);
        sigs[2] = _sign(d, pk3);

        bool ok = messenger.verifyDecision(d, sigs);
        assertTrue(ok, "3 valid guardian signatures must pass");
    }

    // ============ INVARIANTE 8: firme da non-guardian ============
    function test_NonGuardianSignaturesIgnored() public {
        DecisionLib.Decision memory d = _buildDecision(8);
        decisionRegistry.record(d);

        // 3 firme da chiavi che NON sono guardian registrati
        uint256 rnd1 = 0xDEADBEEF00000000000000000000000000000000000000000000000000000001;
        uint256 rnd2 = 0xDEADBEEF00000000000000000000000000000000000000000000000000000002;
        uint256 rnd3 = 0xDEADBEEF00000000000000000000000000000000000000000000000000000003;

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(d, rnd1);
        sigs[1] = _sign(d, rnd2);
        sigs[2] = _sign(d, rnd3);

        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "non-guardian signatures must not count");
    }

    // ============ INVARIANTE 9: firme duplicate ============
    function test_DuplicateSignaturesCountOnce() public {
        DecisionLib.Decision memory d = _buildDecision(9);
        decisionRegistry.record(d);

        // 3 firme dello stesso guardian (pk1)
        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(d, pk1);
        sigs[1] = _sign(d, pk1);
        sigs[2] = _sign(d, pk1);

        bool ok = messenger.verifyDecision(d, sigs);
        assertFalse(ok, "duplicate signatures must count once, not reach threshold");
    }
}
