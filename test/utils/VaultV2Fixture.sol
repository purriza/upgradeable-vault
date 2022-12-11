// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "src/WETH9.sol";
import "src/OmniToken.sol";
import "src/EternalStorageProxy.sol";
import "src/VaultV2.sol";

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract VaultV2Fixture is Test {

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

    EternalStorageProxy public goerliProxy;
    EternalStorageProxy public bnbProxy;

    //
    // Vault
    //

    VaultV2 public goerliVault;
    VaultV2 public bnbVault;

    //
    // Tokens
    //

    WETH9 public weth;
    OmniToken public goerliToken;
    OmniToken public bnbToken;
    address public uniswapLPTokenAddressGoerli;
    address public uniswapLPTokenAddressBNB;

    // Deployer address
    address public deployer = vm.addr(1500);

    // Depositor addresses
    address public depositor1 = vm.addr(1501);
    address public depositor2 = vm.addr(1502);
    address public depositor3 = vm.addr(1503);
    address public depositor4 = vm.addr(1504);

    function setUp() public virtual {
        // Label addresses
        vm.label(deployer, "Deployer");
        vm.label(depositor1, "Depositor 1");
        vm.label(depositor2, "Depositor 2");
        vm.label(depositor3, "Depositor 3");
        vm.label(depositor4, "Depositor 4");

        // Fund deployer wallet
        vm.deal(deployer, 1000 ether);

        // Initial depositors balance
        vm.deal(depositor1, 5 ether);
        vm.deal(depositor2, 5 ether);
        vm.deal(depositor3, 5 ether);
        vm.deal(depositor4, 5 ether);

        vm.startPrank(deployer);

        // Layer Zero Omnichain Endpoints
        address goerliEndpoint = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
        address bnbEndpoint = 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1;

        // Goerli Token
        goerliToken = new OmniToken(goerliEndpoint);
        goerliToken.mint(); // TO-DO Token only mintable from the Vault

        // BNB Token
        bnbToken = new OmniToken(bnbEndpoint);
        bnbToken.mint();

        // Setup the Vault contracts
        //goerliVault = new VaultV2(goerliEndpoint);
        goerliVault = new VaultV2();
        //bnbVault = new VaultV2(goerliEndpoint);
        bnbVault = new VaultV2();

        // Setup the EternalStorageProxy contracts
        goerliProxy = new EternalStorageProxy(address(goerliVault));
        bnbProxy = new EternalStorageProxy(address(bnbVault));

        // Setup Token contracts
        weth = new WETH9();

        vm.label(address(weth), "WETH");
        vm.label(address(goerliToken), "OMT");
        vm.label(address(bnbToken), "OMT");

        // LAYER ZERO OMNICHAIN

        // Set the trusted remotes between chains
        /*(bool success, ) = address(goerliProxy).call(
            abi.encodeWithSignature(
                "setTrustedRemote(uint16,bytes)", 
                goerliEndpoint,
                
            )
        );
        require(success);

        (success, ) = address(bnbProxy).call(
            abi.encodeWithSignature(
                "setTrustedRemote(uint16,bytes)", 
                bnbEndpoint,
                
            )
        );
        require(success);*/

        // TO-DO ENDPOINT MOCK
        //this.lzEndpointMock.setDestLzEndpoint(address(goerliProxy), this.lzEndpointMock.address)
        //this.lzEndpointMock.setDestLzEndpoint(address(bnbProxy), this.lzEndpointMock.address)

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

        // Create pair WETH <-> Goerli Token and add liquidity
        goerliToken.approve(router, UNISWAP_INITIAL_TOKEN_RESERVE);
        (bool success, ) = router.call{value: UNISWAP_INITIAL_WETH_RESERVE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                address(goerliToken), 
                UNISWAP_INITIAL_TOKEN_RESERVE, 
                0, 
                0, 
                deployer, 
                block.timestamp * 2
            )
        );
        require(success);

        // Get the pair to interact with
        (, bytes memory data) = factory.call(abi.encodeWithSignature("getPair(address,address)", address(goerliToken), address(weth)));
        uniswapLPTokenAddressGoerli = abi.decode(data, (address));

        // Sanity check LP Tokens
        (, data) = uniswapLPTokenAddressGoerli.call(abi.encodeWithSignature("balanceOf(address)", deployer));
        uint256 deployerBalanceGoerli = abi.decode(data, (uint256));
        assertGt(deployerBalanceGoerli, 0);

        // Setup initial token balance
        goerliToken.transfer(address(goerliProxy), UNISWAP_INITIAL_TOKEN_RESERVE); 

        goerliToken.transfer(depositor1, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        goerliToken.transfer(depositor2, DEPOSITOR_INITIAL_TOKEN_BALANCE);

        // Add liquidity to the pair to get Uniswap LP tokens for every depositor
        // And checking the balance of the LP tokens afterwards
        goerliToken.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor1, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(goerliToken),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor1,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor1, "Depositor 1 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddressGoerli.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1Balance = abi.decode(data, (uint256));
        assertGt(depositor1Balance, 0);

        goerliToken.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor2, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(goerliToken),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor2,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor2, "Depositor 2 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddressGoerli.call(abi.encodeWithSignature("balanceOf(address)", depositor2));
        uint256 depositor2Balance = abi.decode(data, (uint256));
        assertGt(depositor2Balance, 0);

        // Once we have the uniswapLPTokenAddressGoerli, we initialize the Goerli Vault through the Proxy
        (success, ) = address(goerliProxy).call(
            abi.encodeWithSignature(
                "initialize(uint256,address,address)", 
                10 ** 10,
                uniswapLPTokenAddressGoerli,
                address(goerliToken)
            )
        );
        assertGt(goerliToken.balanceOf(address(goerliProxy)), 0);

        // Create pair WETH <-> BNB Token and add liquidity
        bnbToken.approve(router, UNISWAP_INITIAL_TOKEN_RESERVE);
        (success, ) = router.call{value: UNISWAP_INITIAL_WETH_RESERVE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                address(bnbToken), 
                UNISWAP_INITIAL_TOKEN_RESERVE, 
                0, 
                0, 
                deployer, 
                block.timestamp * 2
            )
        );
        require(success);

        // Get the pair to interact with
        (, data) = factory.call(abi.encodeWithSignature("getPair(address,address)", address(bnbToken), address(weth)));
        uniswapLPTokenAddressBNB = abi.decode(data, (address));

        // Sanity check LP Tokens
        (, data) = uniswapLPTokenAddressBNB.call(abi.encodeWithSignature("balanceOf(address)", deployer));
        uint256 deployerBalanceBnbToken = abi.decode(data, (uint256));
        assertGt(deployerBalanceBnbToken, 0);

        // Setup initial token balance
        goerliToken.transfer(address(bnbProxy), UNISWAP_INITIAL_TOKEN_RESERVE); 

        goerliToken.transfer(depositor3, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        goerliToken.transfer(depositor4, DEPOSITOR_INITIAL_TOKEN_BALANCE);

        bnbToken.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor3, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(bnbToken),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor3,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor3, "Depositor 3 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddressBNB.call(abi.encodeWithSignature("balanceOf(address)", depositor3));
        uint256 depositor3Balance = abi.decode(data, (uint256));
        assertGt(depositor3Balance, 0);

        bnbToken.approve(router, DEPOSITOR_INITIAL_TOKEN_BALANCE);
        (bool liquidityDepositor4, ) = router.call{value: DEPOSITOR_INITIAL_WETH_BALANCE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                address(bnbToken),
                DEPOSITOR_INITIAL_TOKEN_BALANCE,
                0,
                0,
                depositor4,
                block.timestamp * 2
            )
        );
        require(liquidityDepositor4, "Depositor 4 - addLiquidityEth FAILED");

        (, data) = uniswapLPTokenAddressBNB.call(abi.encodeWithSignature("balanceOf(address)", depositor4));
        uint256 depositor4Balance = abi.decode(data, (uint256));
        assertGt(depositor4Balance, 0);

        // Once we have the uniswapLPTokenAddressBNB, we initialize the BNB Vault through the Proxy
        (success, ) = address(bnbProxy).call(
            abi.encodeWithSignature(
                "initialize(uint256,address,address)", 
                10 ** 10,
                uniswapLPTokenAddressBNB,
                address(bnbToken)
            )
        );
        assertGt(bnbToken.balanceOf(address(bnbProxy)), 0);

        vm.stopPrank();
    }
}