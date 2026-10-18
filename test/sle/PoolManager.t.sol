// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolManager} from "../../contracts/sle/core/PoolManager.sol";
import {PoolRegistry} from "../../contracts/sle/core/PoolRegistry.sol";
import {ConstantProductCurve} from "../../contracts/sle/curves/ConstantProductCurve.sol";
import {IPoolManager} from "../../contracts/sle/interfaces/IPoolManager.sol";
import {SLEAddressProvider} from "../../contracts/sle/core/SLEAddressProvider.sol";
import {ICurve} from "../../contracts/sle/interfaces/ICurve.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @dev Token fee-on-transfer: trasferisce 1% in meno
contract MockFeeToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

/// @dev Curva buggata: output enorme (test safety net)
contract MaliciousCurve is ICurve {
    function getAmountOut(uint256, uint256, uint256) external pure returns (uint256) {
        return type(uint128).max;
    }
    function getAmountIn(uint256, uint256, uint256) external pure returns (uint256) { return 0; }
    function name() external pure returns (string memory) { return "Malicious"; }
}

/// @dev MockRouter: simula il flusso reale del Router.
///      transferFrom(utente -> router), approve(pm), pm.xxx()
contract MockRouter {
    PoolManager public pm;

    function setPoolManager(address _pm) external { pm = PoolManager(_pm); }

    function swap(
        bytes32 poolId, bool zeroForOne, uint256 amountIn, uint256 minAmountOut,
        address recipient, uint256 deadline, uint256 feeBps, address payer
    ) external returns (uint256) {
        // Trova il token in ingresso
        (address t0, address t1) = pm.registry().getPool(poolId).token0 == address(0)
            ? (address(0), address(0))
            : (pm.registry().getPool(poolId).token0, pm.registry().getPool(poolId).token1);
        address tokenIn = zeroForOne ? t0 : t1;

        // utente -> router
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // router approva pm
        IERC20(tokenIn).approve(address(pm), amountIn);

        // pm.swap (msg.sender = router)
        return pm.swap(poolId, zeroForOne, amountIn, minAmountOut, recipient, deadline, feeBps, payer);
    }

    function addLiquidity(
        bytes32 poolId, uint256 amount0, uint256 amount1, address onBehalfOf
    ) external returns (uint256) {
        PoolRegistry.PoolInfo memory pool = pm.registry().getPool(poolId);
        // Se il pool non esiste, lascia che pm.addLiquidity reverta con PoolNotActive
        if (pool.curve == address(0)) {
            return pm.addLiquidity(poolId, amount0, amount1, onBehalfOf);
        }

        IERC20(pool.token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(pool.token1).transferFrom(msg.sender, address(this), amount1);
        IERC20(pool.token0).approve(address(pm), amount0);
        IERC20(pool.token1).approve(address(pm), amount1);

        return pm.addLiquidity(poolId, amount0, amount1, onBehalfOf);
    }

    function removeLiquidity(
        bytes32 poolId, uint256 lpAmount, address owner, address recipient
    ) external returns (uint256, uint256) {
        // Nessun trasferimento in ingresso: pm manda i token al recipient
        return pm.removeLiquidity(poolId, lpAmount, owner, recipient);
    }
}

contract PoolManagerTest is Test {
    PoolManager internal pm;
    PoolRegistry internal registry;
    ConstantProductCurve internal curve;
    MockRouter internal router;
    SLEAddressProvider internal provider;

    MockERC20 internal token0;
    MockERC20 internal token1;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);

    bytes32 internal poolId;

    uint256 internal constant INIT0 = 1_000_000e18;
    uint256 internal constant INIT1 = 1_000_000e18;

    function setUp() public {
        curve = new ConstantProductCurve();
        registry = new PoolRegistry(owner);

        // Ordine: provider -> PM(registry, provider) -> router -> setEndpoints(router, pm)
        provider = new SLEAddressProvider(owner);
        router = new MockRouter();
        pm = new PoolManager(address(registry), address(provider));
        router.setPoolManager(address(pm));

        vm.prank(owner);
        provider.setEndpoints(address(router), address(pm));

        token0 = new MockERC20("Token0", "T0");
        token1 = new MockERC20("Token1", "T1");
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        poolId = keccak256(abi.encode(address(token0), address(token1), address(curve)));

        // Registra pool
        vm.prank(owner);
        registry.whitelistCurve(address(curve), true);
        vm.prank(owner);
        registry.registerPool(poolId, address(curve), address(token0), address(token1));
        vm.prank(owner);
        registry.activatePool(poolId);

        // Mint + approve al ROUTER (non al PoolManager!)
        token0.mint(alice, 10_000_000e18);
        token1.mint(alice, 10_000_000e18);
        token0.mint(bob, 10_000_000e18);
        token1.mint(bob, 10_000_000e18);
        token0.mint(address(this), 10_000_000e18);
        token1.mint(address(this), 10_000_000e18);

        vm.prank(alice);
        token0.approve(address(router), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(router), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(router), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(router), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        // Alice deposita liquidità iniziale
        vm.prank(alice);
        router.addLiquidity(poolId, INIT0, INIT1, alice);
    }

    // ───────────── Access control ─────────────

    function test_swap_directCallReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.UnauthorizedCaller.selector, address(this)));
        pm.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
    }

    function test_addLiquidity_directCallReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.UnauthorizedCaller.selector, address(this)));
        pm.addLiquidity(poolId, 1000e18, 1000e18, address(this));
    }

    function test_removeLiquidity_directCallReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.UnauthorizedCaller.selector, address(this)));
        pm.removeLiquidity(poolId, 1, address(this), address(this));
    }

    function test_constructor_zeroProviderReverts() public {
        vm.expectRevert(IPoolManager.ZeroAddress.selector);
        new PoolManager(address(registry), address(0));
    }

    function test_swap_providerNotConfiguredReverts() public {
        // Deploy nuovo provider (non configurato) e nuovo PM
        SLEAddressProvider p2 = new SLEAddressProvider(owner);
        PoolManager pm2 = new PoolManager(address(registry), address(p2));
        // Provider non configurato -> router() = address(0) -> chiamate rifiutate
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.UnauthorizedCaller.selector, address(this)));
        pm2.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
    }

    // ───────────── Add liquidity ─────────────

    function test_addLiquidity_firstDeposit_locksMinimum() public view {
        uint256 aliceLP = pm.getLPBalance(poolId, alice);
        uint256 total = pm.getTotalLPSupply(poolId);
        assertEq(total, aliceLP + pm.MINIMUM_LIQUIDITY());
    }

    function test_addLiquidity_LPAssignedToOnBehalfOf() public {
        // Bob chiama router, ma LP vanno ad alice (onBehalfOf)
        vm.prank(bob);
        token0.approve(address(router), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(router), type(uint256).max);
        // Bob trasferisce token al router, poi router chiama pm con onBehalfOf=alice
        // Ma in questo test il msg.sender per pm è il ROUTER, non bob.
        // Quindi dobbiamo impersonare il router (o usare router come intermediario)
        // Per testare la logica onBehalfOf: chiamare router da bob, ma router chiama pm.
        // Il router trasferisce da bob a pm tramite il proprio balance.
        // Semplicità: bob approva il router, router usa transferFrom.
        // Ma il MockRouter non fa transferFrom. Facciamo un test diretto simulando il router:
        uint256 aliceBefore = pm.getLPBalance(poolId, alice);
        uint256 bobBefore = pm.getLPBalance(poolId, bob);
        vm.prank(alice);
        router.addLiquidity(poolId, 100_000e18, 100_000e18, bob); // LP a bob
        assertGt(pm.getLPBalance(poolId, bob), bobBefore);
        assertEq(pm.getLPBalance(poolId, alice), aliceBefore);
    }

    function test_addLiquidity_zeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(IPoolManager.ZeroAmount.selector);
        router.addLiquidity(poolId, 0, 100e18, alice);
    }

    function test_addLiquidity_poolNotActiveReverts() public {
        bytes32 fake = keccak256("fake");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.PoolNotActive.selector, fake));
        router.addLiquidity(fake, 100e18, 100e18, alice);
    }

    function test_addLiquidity_nonProportionalReverts() public {
        // Alice ha pool 1M/1M. Bob prova 1000/2000 -> fuori tolleranza
        vm.prank(bob);
        vm.expectRevert(IPoolManager.InsufficientLiquidity.selector);
        router.addLiquidity(poolId, 1000e18, 2000e18, bob);
    }

    function test_addLiquidity_proportionalWithinTolerance() public {
        // Proporzione 1:1, piccolo scostamento (1 bps)
        vm.prank(bob);
        uint256 lp = router.addLiquidity(poolId, 100_000e18, 100_001e18, bob);
        assertGt(lp, 0);
    }

    function test_addLiquidity_justOverToleranceReverts() public {
        // Scostamento > 1 bps (0.01%)
        vm.prank(bob);
        vm.expectRevert(IPoolManager.InsufficientLiquidity.selector);
        router.addLiquidity(poolId, 100_000e18, 100_050e18, bob); // 0.05% > 1 bps
    }

    // ───────────── Swap ─────────────

    function test_swap_zeroForOne_happyPath() public {
        uint256 out = router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
        assertGt(out, 0);
    }

    function test_swap_deadlineExpired() public {
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.DeadlineExpired.selector, block.timestamp - 1));
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp - 1, 30, address(this));
    }

    function test_swap_zeroAmount() public {
        vm.expectRevert(IPoolManager.ZeroAmount.selector);
        router.swap(poolId, true, 0, 0, bob, block.timestamp + 100, 30, address(this));
    }

    function test_swap_feeTooHigh() public {
        vm.expectRevert(abi.encodeWithSelector(IPoolManager.FeeTooHigh.selector, 201, 200));
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 201, address(this));
    }

    function test_swap_zeroRecipientReverts() public {
        vm.expectRevert(IPoolManager.ZeroAddress.selector);
        router.swap(poolId, true, 1000e18, 0, address(0), block.timestamp + 100, 30, address(this));
    }

    function test_swap_slippageExceeded() public {
        vm.expectRevert();
        router.swap(poolId, true, 1000e18, 1000e18, bob, block.timestamp + 100, 30, address(this));
    }

    function test_swap_feeAccrued() public {
        (uint256 fee0Before,) = pm.getFeesAccrued(poolId);
        router.swap(poolId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
        (uint256 fee0After,) = pm.getFeesAccrued(poolId);
        assertEq(fee0After - fee0Before, 3e18); // 1000 * 30 / 10000
    }

    function test_swap_tinyAmountFeeEqualsInputReverts() public {
        // feeBps=200 (max), amountIn=1 -> feeAmount = ceil(1*200/10000) = 1 -> amountAfterFee = 0
        vm.expectRevert(IPoolManager.ZeroAmount.selector);
        router.swap(poolId, true, 1, 0, bob, block.timestamp + 100, 200, address(this));
    }

    // ───────────── Safety net ─────────────

    function test_swap_maliciousCurve_reverts() public {
        MaliciousCurve evil = new MaliciousCurve();
        vm.prank(owner);
        registry.whitelistCurve(address(evil), true);
        bytes32 evilId = keccak256(abi.encode(address(token0), address(token1), address(evil)));
        vm.prank(owner);
        registry.registerPool(evilId, address(evil), address(token0), address(token1));
        vm.prank(owner);
        registry.activatePool(evilId);
        vm.prank(alice);
        router.addLiquidity(evilId, INIT0, INIT1, alice);

        vm.expectRevert();
        router.swap(evilId, true, 1000e18, 0, bob, block.timestamp + 100, 30, address(this));
    }

    // ───────────── Remove liquidity ─────────────

    function test_removeLiquidity_partial() public {
        uint256 lp = pm.getLPBalance(poolId, alice);
        vm.prank(alice);
        (uint256 a0, uint256 a1) = router.removeLiquidity(poolId, lp / 2, alice, alice);
        assertGt(a0, 0);
        assertGt(a1, 0);
        assertEq(pm.getLPBalance(poolId, alice), lp - lp / 2);
    }

    function test_removeLiquidity_ownerWithNoLPReverts() public {
        address charlie = address(0xDEAD);
        vm.prank(bob);
        vm.expectRevert(IPoolManager.InsufficientLiquidity.selector);
        router.removeLiquidity(poolId, 1, charlie, bob);
    }

    function test_removeLiquidity_zeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(IPoolManager.ZeroAmount.selector);
        router.removeLiquidity(poolId, 0, alice, alice);
    }

    function test_removeLiquidity_insufficientLP() public {
        uint256 lp = pm.getLPBalance(poolId, alice);
        vm.prank(alice);
        vm.expectRevert(IPoolManager.InsufficientLiquidity.selector);
        router.removeLiquidity(poolId, lp + 1, alice, alice);
    }

    // ───────────── Fee-on-transfer ─────────────

    function test_addLiquidity_feeOnTransferReverts() public {
        MockFeeToken feeToken = new MockFeeToken("Fee", "FEE");
        (address t0, address t1) = address(feeToken) < address(token0) ? (address(feeToken), address(token0)) : (address(token0), address(feeToken));
        bytes32 fid = keccak256(abi.encode(t0, t1, address(curve)));
        vm.prank(owner);
        registry.registerPool(fid, address(curve), t0, t1);
        vm.prank(owner);
        registry.activatePool(fid);

        // Mint direttamente al router (bypassa il fee-on-transfer in ingresso)
        feeToken.mint(address(router), 1_000_000e18);
        token0.mint(address(router), 1_000_000e18);
        // Approva pm dal router (impersona il router)
        vm.startPrank(address(router));
        feeToken.approve(address(pm), type(uint256).max);
        token0.approve(address(pm), type(uint256).max);

        // pm.addLiquidity riceve dal router (feeToken perde 1% -> balance delta != amount -> revert)
        (address a0, address a1) = address(feeToken) < address(token0) ? (address(feeToken), address(token0)) : (address(token0), address(feeToken));
        uint256 amtFee = a0 == address(feeToken) ? 1000e18 : 0;
        uint256 amtTok = a1 == address(feeToken) ? 1000e18 : 0;
        if (amtFee == 0) { amtFee = 1000e18; amtTok = 0; }
        uint256 a0Amt = a0 == address(feeToken) ? 1000e18 : 1000e18;
        uint256 a1Amt = 1000e18;

        vm.expectRevert(IPoolManager.FeeOnTransferNotSupported.selector);
        pm.addLiquidity(fid, a0Amt, a1Amt, alice);
        vm.stopPrank();
    }

    // ───────────── Invarianti fuzz ─────────────

    function testFuzz_swap_kNeverDecreases(uint256 amountIn, uint256 feeBps) public {
        amountIn = bound(amountIn, 1e6, 10_000e18);
        feeBps = bound(feeBps, 0, 200);

        (uint256 r0B, uint256 r1B) = pm.getReserves(poolId);
        uint256 kB = r0B * r1B;

        router.swap(poolId, true, amountIn, 0, bob, block.timestamp + 100, feeBps, address(this));

        (uint256 r0A, uint256 r1A) = pm.getReserves(poolId);
        assertGe(r0A * r1A, kB, "k decreased");
    }

    function testFuzz_lpSupplyCoherent(uint256 lpFrac) public {
        lpFrac = bound(lpFrac, 1, 100);
        uint256 aliceLP = pm.getLPBalance(poolId, alice);
        uint256 totalBefore = pm.getTotalLPSupply(poolId);
        uint256 toRemove = (aliceLP * lpFrac) / 100;
        if (toRemove == 0) return;

        vm.prank(alice);
        router.removeLiquidity(poolId, toRemove, alice, alice);

        assertEq(pm.getTotalLPSupply(poolId), totalBefore - toRemove);
    }

    function testFuzz_roundingWithdrawalExact(uint256 lpFrac) public {
        // Genera fee con uno swap
        router.swap(poolId, true, 10_000e18, 0, bob, block.timestamp + 100, 100, address(this));

        lpFrac = bound(lpFrac, 1, 100);
        uint256 aliceLP = pm.getLPBalance(poolId, alice);
        uint256 toRemove = (aliceLP * lpFrac) / 100;
        if (toRemove == 0) return;

        (uint256 fee0Before, uint256 fee1Before) = pm.getFeesAccrued(poolId);
        (uint256 r0Before, uint256 r1Before) = pm.getReserves(poolId);
        uint256 supplyBefore = pm.getTotalLPSupply(poolId);

        vm.prank(alice);
        (uint256 a0, uint256 a1) = router.removeLiquidity(poolId, toRemove, alice, alice);

        (uint256 fee0After, uint256 fee1After) = pm.getFeesAccrued(poolId);
        (uint256 r0After, uint256 r1After) = pm.getReserves(poolId);

        // Verifica che amount = (fee + reserve) delta esatti
        assertEq(a0, (fee0Before - fee0After) + (r0Before - r0After), "amount0 mismatch");
        assertEq(a1, (fee1Before - fee1After) + (r1Before - r1After), "amount1 mismatch");
        assertEq(pm.getTotalLPSupply(poolId), supplyBefore - toRemove);
    }
}
