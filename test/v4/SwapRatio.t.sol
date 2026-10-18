// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {T2TPoolManager} from "../../contracts/v4/T2TPoolManager.sol";
import {T2TRouter} from "../../contracts/v4/T2TRouter.sol";
import {T2THooks} from "../../contracts/v4/T2THooks.sol";
import {GuardianRegistry} from "../../contracts/governance/GuardianRegistry.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "lib/v4-periphery/test/shared/HookMiner.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IMockERC20 {
    function mint(address, uint256) external;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/// @notice Token ERC20 minimale per il test.
contract TestToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed, address indexed, uint256);
    event Approval(address indexed, address indexed, uint256);

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract SwapRatioTest is Test {
    T2TPoolManager internal pm;
    T2TRouter internal router;
    T2THooks internal hook;
    GuardianRegistry internal greg;
    TestToken internal usdc;   // 6 dec
    TestToken internal timp;   // 18 dec

    address internal owner = address(0xA11CE);
    address internal deployer = address(0xB0B);

    PoolKey internal key;
    uint160 internal SQRT_P_BEFORE;

    function setUp() public {
        vm.deal(deployer, 100 ether);

        // 1. MockUSDC (6 dec) e tTwoTrader (18 dec)
        usdc = new TestToken("MockUSDC", "USDC", 6);
        timp = new TestToken("Test TwoTrader", "tTwoTrader", 18);

        // 2. GuardianRegistry (serve per l'hook)
        GuardianRegistry gregImpl = new GuardianRegistry();
        bytes memory regInit = abi.encodeWithSelector(
            GuardianRegistry.initialize.selector,
            owner, 1 ether, 7 days
        );
        greg = GuardianRegistry(address(new ERC1967Proxy(address(gregImpl), regInit)));

        // 3. PoolManager
        T2TPoolManager pmImpl = new T2TPoolManager();
        bytes memory pmInit = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address)")),
            owner
        );
        pm = T2TPoolManager(address(new ERC1967Proxy(address(pmImpl), pmInit)));

        // 4. Hook (con CREATE2 per i flag 0xC0)
        // Nel test il deployer del new{ salt } e' il test contract stesso.
        address create2Deployer = address(this);
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory creationCode = type(T2THooks).creationCode;
        bytes memory args = abi.encode(IPoolManager(address(pm)), greg, owner);
        (, bytes32 salt) = HookMiner.find(create2Deployer, flags, creationCode, args);
        hook = new T2THooks{salt: salt}(IPoolManager(address(pm)), greg, owner);

        // Verifica che i flag siano corretti
        uint160 masked = uint160(address(hook)) & Hooks.ALL_HOOK_MASK;
        require(masked == flags, "HookAddressNotValid in test");

        // 5. Router
        router = new T2TRouter(IPoolManager(address(pm)), owner);

        // 6. Ordina i token
        address token0;
        address token1;
        if (uint160(address(timp)) < uint160(address(usdc))) {
            token0 = address(timp);
            token1 = address(usdc);
        } else {
            token0 = address(usdc);
            token1 = address(timp);
        }

        console.log("=== Ordine token ===");
        console.log("token0:", token0);
        console.log("token1:", token1);

        // 7. PoolKey
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // 8. Inizializza pool al tick -276324 (prezzo 1 tTwoTrader = 1 USDC)
        int24 initialTick = -276324;
        SQRT_P_BEFORE = TickMath.getSqrtPriceAtTick(initialTick);
        console.log("=== Inizializzazione pool ===");
        console.log("initial tick:", initialTick);
        console.log("sqrtP:", uint256(SQRT_P_BEFORE));

        vm.prank(owner);
        pm.initialize(key, SQRT_P_BEFORE);

        // 9. Whitelist
        vm.startPrank(owner);
        router.allowToken(address(timp));
        router.allowToken(address(usdc));
        router.allowPair(address(timp), address(usdc));
        router.allowPool(key);
        vm.stopPrank();

        // 10. Mint token al deployer
        usdc.mint(deployer, 1_000_000 * 10 ** 6);   // 1M USDC
        timp.mint(deployer, 1_000_000 * 10 ** 18);  // 1M tTwoTrader

        // 11. Approve router
        vm.startPrank(deployer);
        usdc.approve(address(router), type(uint256).max);
        timp.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapRatio_10_USDC_For_tIMP() public {
        // === 1. AddLiquidity: 100k tTwoTrader + 100k USDC ===
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;

        if (uint160(address(timp)) < uint160(address(usdc))) {
            // token0 = tTwoTrader, token1 = USDC
            tickLower = -286320;
            tickUpper = -266340;
            amount0 = 100_000 * 10 ** 18;  // 100k tTwoTrader
            amount1 = 100_000 * 10 ** 6;   // 100k USDC
        } else {
            // token0 = USDC, token1 = tTwoTrader
            tickLower = 266340;
            tickUpper = 286320;
            amount0 = 100_000 * 10 ** 6;   // 100k USDC
            amount1 = 100_000 * 10 ** 18;  // 100k tTwoTrader
        }

        console.log("=== AddLiquidity ===");
        console.log("tickLower:", tickLower);
        console.log("tickUpper:", tickUpper);
        console.log("amount0:", amount0);
        console.log("amount1:", amount1);

        vm.prank(deployer);
        BalanceDelta liqDelta = router.addLiquidity(
            key, tickLower, tickUpper, amount0, amount1, SQRT_P_BEFORE, deployer, block.timestamp + 600
        );

        console.log("liq delta.amount0:", liqDelta.amount0());
        console.log("liq delta.amount1:", liqDelta.amount1());

        // === 2. Saldi pool prima dello swap ===
        uint256 poolUsdcBefore = usdc.balanceOf(address(pm));
        uint256 poolTimpBefore = timp.balanceOf(address(pm));
        uint256 depUsdcBefore = usdc.balanceOf(deployer);
        uint256 depTimpBefore = timp.balanceOf(deployer);

        console.log("=== Prima dello swap ===");
        console.log("pool USDC:", poolUsdcBefore);
        console.log("pool tTwoTrader:", poolTimpBefore);
        console.log("deployer USDC:", depUsdcBefore);
        console.log("deployer tTwoTrader:", depTimpBefore);

        // === 3. Swap: 10 USDC -> tTwoTrader ===
        bool zeroForOne = uint160(address(usdc)) < uint160(address(timp)) ? false : true;
        // Se token0=tTwoTrader, token1=USDC: USDC e' token1 -> zeroForOne = false
        // Se token0=USDC, token1=tTwoTrader: USDC e' token0 -> zeroForOne = true
        if (uint160(address(timp)) < uint160(address(usdc))) {
            zeroForOne = false; // USDC (token1) -> tTwoTrader (token0)
        } else {
            zeroForOne = true;  // USDC (token0) -> tTwoTrader (token1)
        }

        uint256 amountIn = 10 * 10 ** 6; // 10 USDC

        console.log("=== Swap ===");
        console.log("zeroForOne:", zeroForOne);
        console.log("amountIn:", amountIn);

        vm.prank(deployer);
        BalanceDelta swapDelta = router.swapExactInput(
            key, zeroForOne, amountIn, 0, deployer, block.timestamp + 600
        );

        console.log("=== Swap delta ===");
        console.log("delta.amount0:", swapDelta.amount0());
        console.log("delta.amount1:", swapDelta.amount1());

        // === 4. Saldi pool dopo lo swap ===
        uint256 poolUsdcAfter = usdc.balanceOf(address(pm));
        uint256 poolTimpAfter = timp.balanceOf(address(pm));
        uint256 depUsdcAfter = usdc.balanceOf(deployer);
        uint256 depTimpAfter = timp.balanceOf(deployer);

        console.log("=== Dopo lo swap ===");
        console.log("pool USDC:", poolUsdcAfter);
        console.log("pool tTwoTrader:", poolTimpAfter);
        console.log("deployer USDC:", depUsdcAfter);
        console.log("deployer tTwoTrader:", depTimpAfter);

        // === 5. Verifica ===
        // Atteso: -10 USDC (raw 1e7), +10 tTwoTrader (raw 1e19)
        uint256 depUsdcDelta = depUsdcBefore - depUsdcAfter;
        uint256 depTimpDelta = depTimpAfter - depTimpBefore;

        console.log("=== Delta deployer ===");
        console.log("USDC out (raw):", depUsdcDelta);
        console.log("tTwoTrader in (raw):", depTimpDelta);
        console.log("ratio tTwoTrader/USDC (raw * 1e6):", depTimpDelta / 1e6);

        // Il rapporto ideale e' 1e12 (10 USDC -> 10e18 tTwoTrader raw, 1e6 -> 1e12)
        // Tolleranza 10% per fee e slippage
        uint256 expectedTimpRaw = amountIn * 1e12;
        uint256 minTimpRaw = expectedTimpRaw * 90 / 100;

        assertGe(depTimpDelta, minTimpRaw, "Output tTwoTrader troppo basso");
        assertLe(depTimpDelta, expectedTimpRaw * 110 / 100, "Output tTwoTrader troppo alto");
    }
}
