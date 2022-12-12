// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "src/WETH9.sol";
import "src/OmniToken.sol";
import "src/EternalStorageProxy.sol";
import "src/VaultV1.sol";

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract VaultFixture is Test {

    //
    // Constants
    //

    uint256 public constant UNISWAP_INITIAL_TOKEN_RESERVE = 1000 ether;
    uint256 public constant UNISWAP_INITIAL_WETH_RESERVE = 100 ether;

    uint256 public constant DEPOSITOR_INITIAL_TOKEN_BALANCE = 50 ether;
    uint256 public constant DEPOSITOR_INITIAL_WETH_BALANCE = 5 ether;

    //
    // Uniswap V2 contracts
    //

    address public factory;
    address public router;
    address public exchange;

    //
    // Proxy
    // 

    EternalStorageProxy public proxy;

    //
    // Vault
    //

    VaultV1 public vault;

    //
    // Tokens
    //

    WETH9 public weth;
    OmniToken public token;
    OmniToken public bnbToken;
    address public uniswapLPTokenAddress;

    // Deployer address
    address public deployer = vm.addr(1500);

    // Depositor addresses
    address public depositor1 = vm.addr(1501);
    address public depositor2 = vm.addr(1502);
    address public depositor3 = vm.addr(1503);
    address public depositor4 = vm.addr(1504);
    address public depositor5 = vm.addr(1504);

    function setUp() public virtual {
        // Label addresses
        vm.label(deployer, "Deployer");
        vm.label(depositor1, "Depositor 1");
        vm.label(depositor2, "Depositor 2");
        vm.label(depositor3, "Depositor 3");
        vm.label(depositor4, "Depositor 4");
        vm.label(depositor5, "Depositor 5");

        // Fund deployer wallet
        vm.deal(deployer, 1000 ether);

        // Initial depositors balance
        vm.deal(depositor1, 5 ether);
        vm.deal(depositor2, 5 ether);
        vm.deal(depositor3, 5 ether);
        vm.deal(depositor4, 5 ether);
        vm.deal(depositor5, 5 ether);

        vm.startPrank(deployer);

        // Setup the Vault contract
        vault = new VaultV1();

        // Setup the EternalStorageProxy contract
        proxy = new EternalStorageProxy(address(vault));

        // Setup Token contracts
        weth = new WETH9();
        //token = OmniToken(proxy.rewardsToken());

        // LAYER ZERO OMNICHAIN

        // Goerli Testnet Endpoint
        token = new OmniToken(0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23);
        token.mint(); // TO-DO Token only mintable from the Vault

        // BNB Testnet Endpoint
        bnbToken = new OmniToken(0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1);
        //bnbToken.mint();

        vm.label(address(weth), "WETH");
        vm.label(address(token), "OMT");

        // UNISWAP
        
        // Setup Uniswap V2 contracts
        factory = deployCode("UniswapV2Factory.sol", abi.encode(address(0)));
        
        // To get the 
        /*(, bytes memory data) = factory.call(abi.encodeWithSignature("getHash()"));
        bytes32 factoryHash = abi.decode(data, (bytes32));
        emit log_bytes32(factoryHash);*/

        router = deployCode("UniswapV2Router02.sol", abi.encode(address(factory),address(weth)));
        vm.label(factory, "Factory");
        vm.label(router, "Router");

        // Create pair WETH <-> Token and add liquidity
        token.approve(router, UNISWAP_INITIAL_TOKEN_RESERVE);
        (bool success, ) = router.call{value: UNISWAP_INITIAL_WETH_RESERVE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                address(token), 
                UNISWAP_INITIAL_TOKEN_RESERVE, 
                0, 
                0, 
                deployer, 
                block.timestamp * 2
            )
        );
        require(success);

        // Get the pair to interact with
        (, bytes memory data) = factory.call(abi.encodeWithSignature("getPair(address,address)", address(token), address(weth)));
        uniswapLPTokenAddress = abi.decode(data, (address));

        // Sanity check LP Tokens
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", deployer));
        uint256 deployerBalance = abi.decode(data, (uint256));
        assertGt(deployerBalance, 0);

        // Setup initial token balance
        // Should be needed? We pass the token address to the initialize function, so the Omnitoken constructor is not fired (Omnitoken(address) and the mint is not done)
        // Once deployed the initialize function of the Vault should have new Omnitoken()?
        token.transfer(address(proxy), UNISWAP_INITIAL_TOKEN_RESERVE); 

        token.transfer(depositor1, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        token.transfer(depositor2, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        token.transfer(depositor3, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        token.transfer(depositor4, DEPOSITOR_INITIAL_TOKEN_BALANCE);

        // Add liquidity to the pair to get Uniswap LP tokens for every depositor
        // And checking the balance of the LP tokens afterwards
        token.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor1, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(token),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor1,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor1, "Depositor 1 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1Balance = abi.decode(data, (uint256));
        assertGt(depositor1Balance, 0);

        token.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor2, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(token),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor2,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor2, "Depositor 2 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor2));
        uint256 depositor2Balance = abi.decode(data, (uint256));
        assertGt(depositor2Balance, 0);

        token.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor3, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(token),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor3,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor3, "Depositor 3 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor3));
        uint256 depositor3Balance = abi.decode(data, (uint256));
        assertGt(depositor3Balance, 0);

        token.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor4, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(token),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor4,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor4, "Depositor 4 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor4));
        uint256 depositor4Balance = abi.decode(data, (uint256));
        assertGt(depositor4Balance, 0);

        // Once we have the uniswapLPTokenAddress, we initialize the Vault through the Proxy
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "initialize(uint256,address,address)", 
                10 ** 10,
                uniswapLPTokenAddress,
                address(token)
            )
        );
        assertGt(token.balanceOf(address(proxy)), 0);

        vm.stopPrank();
    }
}