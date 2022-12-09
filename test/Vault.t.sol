// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./utils/VaultFixture.sol";

contract VaultTest is VaultFixture {

    function setUp() public override {
        super.setUp();
    }

    // TO-DO
    // Expected, val: Depositor 1: [0xef1D6dB5525B7953bF0B23DB999927E93Cd9cec2]
    // Actual, val: EternalStorageProxy: [0x2e234DAe75C793f67A35089C9d99245E1C58470b]
    function test_upgradeDelegate() public {
        // Unhappy path Nº1 - Trying to transfer ownership without being the owner
        vm.startPrank(depositor1);

        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Only owner"));
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "upgradeDelegate(address)",
                depositor1
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        vm.stopPrank();
        
        vm.startPrank(deployer);

        // Unhappy path Nº2 - Trying to transfer the ownership to address(0)
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Address 0 detected"));
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "upgradeDelegate(address)",
                address(0)
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        // Happy path - Deployer (Being the owner and passing a correct address)
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "upgradeDelegate(address)",
                depositor1
            )
        );
        require(success, "upgradeDelegate FAILED");
        assertEq(proxy.delegate.address, address(depositor1)); 

        vm.stopPrank();
    }

    // TO-DO
    // Expected, val: Depositor 1: [0xef1D6dB5525B7953bF0B23DB999927E93Cd9cec2]
    // Actual, val: EternalStorageProxy: [0x2e234DAe75C793f67A35089C9d99245E1C58470b
    function test_transferOwnership() public {
        // Unhappy path Nº1 - Trying to transfer ownership without being the owner
        vm.startPrank(depositor1);

        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Only owner"));
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "transferOwnership(address)",
                depositor1
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        vm.stopPrank();
        
        vm.startPrank(deployer);

        // Unhappy path Nº2 - Trying to transfer the ownership to address(0)
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Address 0 detected"));
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "transferOwnership(address)",
                address(0)
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        // Happy path - Deployer (Being the owner and passing a correct address)
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "transferOwnership(address)",
                depositor1
            )
        );
        require(success, "transferOwnership FAILED");
        assertEq(proxy.owner.address, address(depositor1));

        vm.stopPrank();
    }

    function test_updateRewardsIssuancePerYear() public {
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Only owner"));
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)",
                100
            )
        );
        assertTrue(status, "expectRevert: call did not revert");
        
        // Happy path - Deployer (Being the owner)
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)",
                100
            )
        );
        require(success, "updateRewardsIssuancePerYear FAILED");
        //assertEq(vault.rewardsIssuancePerYear, uint256(100));

        vm.stopPrank();
    }

    function test_deposit() public {
        // Depositor 1
        vm.startPrank(depositor1);
        
        // Save initial balances
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", address(proxy)));
        uint256 vaultBalanceBefore = abi.decode(data, (uint256));
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1BalanceBefore = abi.decode(data, (uint256));

        // Unhappy path Nº1 - Locking Period has to be 6, 12, 24 o 48 (months)
        //vm.expectRevert(bytes("Locking period has to be 6 months or 1, 2 or 4 years."));
        //vm.expectRevert(bytes("EvmError: Revert"));
        // TO-DO Try to get the error message from the Vault
        // │   │   └─ ← "Locking period has to be 6 months or 1, 2 or 4 years." -> Vault::deposit
        // │   └─ ← "EvmError: Revert" -> EternalStorageProxy::deposit
        // └─ ← "EvmError: Revert" -> VaultTest::test_deposit
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                7
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        // Happy path (If the depositor has approved the Vault to transfer the LP Tokens)
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - deposit(5,6): FAILED");

        // Check final balances
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1BalanceAfter = abi.decode(data, (uint256));
        assertEq(depositor1BalanceAfter, depositor1BalanceBefore - 5);

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", address(proxy)));
        uint256 vaultBalanceAfter = abi.decode(data, (uint256));
        assertEq(vaultBalanceAfter, vaultBalanceBefore + 5);

        vm.stopPrank();
    }

    function test_withdrawDeposit() public {
        // Depositor 1
        vm.startPrank(depositor1);
        
        // Save initial balances
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", address(proxy)));
        uint256 vaultBalanceBefore = abi.decode(data, (uint256));
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1BalanceBefore = abi.decode(data, (uint256));
 
        // Add a deposit
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - deposit(5,6): FAILED");

        // Unhappy path Nº1 - Deposit does not exist
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes(""Deposit does not exist");
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "withdrawDeposit(uint256)", 
                1
            )
        );
        assertTrue(status, "expectRevert: call did not revert");
        vm.stopPrank();

        vm.startPrank(depositor2);
        // Unhappy path Nº2 - Only the depositor can withdraw his tokens
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Only the depositor can withdraw his tokens");
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "withdrawDeposit(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");
        vm.stopPrank();

        vm.startPrank(depositor1);
        // Unhappy path Nº3 - Locking period hasn't ended yet
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Locking period hasn't ended yet");
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "withdrawDeposit(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        // Happy path - The withdraw is done correctly after the locking period has ended
        vm.warp(block.timestamp + 181 days); // 6 months

        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "withdrawDeposit(uint256)", 
                0
            )
        );
        require(success, "Proxy - withdrawDeposit(0): FAILED");

        // Check final balances
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", depositor1));
        uint256 depositor1BalanceAfter = abi.decode(data, (uint256));
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);

        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("balanceOf(address)", address(proxy)));
        uint256 vaultBalanceAfter = abi.decode(data, (uint256));
        assertGt(vaultBalanceBefore, vaultBalanceAfter);

        vm.stopPrank();
    }

    function test_claimRewards() public {
        // Depositor 1
        vm.startPrank(depositor1);
        
        // Save initial balances
        uint256 vaultBalanceBefore = token.balanceOf(address(proxy));
        uint256 depositor1BalanceBefore = token.balanceOf(depositor1);

        // Add a deposit
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - deposit(5,6): FAILED");

        // Unhappy path Nº1 - Deposit does not exist
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes(""Deposit does not exist");
        vm.expectRevert();
        (bool status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        vm.startPrank(depositor2);
        // Unhappy path Nº2 - Only the depositor can withdraw his tokens
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Only the depositor can claim his rewards");
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");
        vm.stopPrank();

        vm.startPrank(depositor1);
        // Unhappy path Nº3 - Pending rewards has to be greater than 0 (You can't deposit and claim in the same block)
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("Pending rewards has to be greater than 0.");
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");
        
        vm.warp(block.timestamp + 180 days); // 6 months

        // Happy path - The rewards are claimed correcly
        token.approve(address(proxy), 100); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");

        // Check final balances
        assertGt(token.balanceOf(depositor1), depositor1BalanceBefore);
        assertGt(vaultBalanceBefore, token.balanceOf(address(proxy)));

        // Unhappy path Nº4 - You should wait until the next block to claim rewards again
        // TO-DO Expect revert with the correct error message
        //vm.expectRevert(bytes("You must wait to claim rewards again");
        vm.expectRevert();
        (status, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        assertTrue(status, "expectRevert: call did not revert");

        vm.stopPrank();
    }

    function test_example1() public {
        // Save initial balances
        // TO-DO This is not the token that the Vault its transfering
        // On the initialize function: rewardsToken = new OmniToken(_rewardsTokenAddress); -> New instance of the contract, not the same
        //uint256 depositor1BalanceBefore = token.balanceOf(depositor1);
        //uint256 depositor2BalanceBefore = token.balanceOf(depositor2);
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);

        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                100
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 2 deposit(5,6): FAILED");
        
        vm.stopPrank();


        vm.warp(block.timestamp + 180 days); // 6 months


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 100); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        //uint256 depositor1BalanceAfter = token.balanceOf(depositor1);
        //assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);

        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 100); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        //uint256 depositor2BalanceAfter = token.balanceOf(depositor2);
        //assertGt(depositor2BalanceAfter, depositor2BalanceBefore);
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();
    }

    function test_example2() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                120
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 2 deposit(5,6): FAILED");

        vm.stopPrank();


        vm.warp(block.timestamp + 360 days); // 1 year


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 100);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);

        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 100);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();
    }

    function test_example3() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        uint256 depositor3BalanceBefore = proxy.rewardsToken().balanceOf(depositor3);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                84
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 2 deposit(5,12): FAILED");
        
        vm.stopPrank();

        // Depositor 3
        vm.startPrank(depositor3);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                24
            )
        );
        require(success, "Proxy - 1 deposit(5,24): FAILED");
        
        vm.stopPrank();


        vm.warp(block.timestamp + 720 days); // 2 años


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 200); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 200);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();

        // Depositor 3
        vm.startPrank(depositor3);
        
        token.approve(address(proxy), 200);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                2
            )
        );
        require(success, "Proxy - claimRewards(2): FAILED");
        uint256 depositor3BalanceAfter = proxy.rewardsToken().balanceOf(depositor3);
        assertGt(depositor3BalanceAfter, depositor3BalanceBefore);

        vm.stopPrank();
    }

    function test_example4() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        uint256 depositor3BalanceBefore = proxy.rewardsToken().balanceOf(depositor3);
        uint256 depositor4BalanceBefore = proxy.rewardsToken().balanceOf(depositor4);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                2520
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 2 deposit(5,12): FAILED");
        
        vm.stopPrank();

        // Depositor 3
        vm.startPrank(depositor3);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                24
            )
        );
        require(success, "Proxy - 3 deposit(5,24): FAILED");
        
        vm.stopPrank();

        // Depositor 4
        vm.startPrank(depositor4);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                48
            )
        );
        require(success, "Proxy - 4 deposit(5,48): FAILED");

        vm.stopPrank();

        vm.warp(block.timestamp + 1460 days); // 4 years

        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 5000); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 5000);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();

        // Depositor 3
        vm.startPrank(depositor3);
        
        token.approve(address(proxy), 5000);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                2
            )
        );
        require(success, "Proxy - claimRewards(2): FAILED");
        uint256 depositor3BalanceAfter = proxy.rewardsToken().balanceOf(depositor3);
        assertGt(depositor3BalanceAfter, depositor3BalanceBefore);

        vm.stopPrank();

        // Depositor 4
        vm.startPrank(depositor4);
        
        token.approve(address(proxy), 5000);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                3
            )
        );
        require(success, "Proxy - claimRewards(3): FAILED");
        uint256 depositor4BalanceAfter = proxy.rewardsToken().balanceOf(depositor4);
        assertGt(depositor4BalanceAfter, depositor4BalanceBefore);

        vm.stopPrank();
    }

    function test_example5() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                120
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        vm.warp(block.timestamp + 90 days); // 3 months

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5)); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 2 deposit(5,6): FAILED");
        
        vm.stopPrank();


        vm.warp(block.timestamp + 180 days); // 6 months


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 50);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 50); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();
    }

    function test_example6() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                120
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5)); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        vm.warp(block.timestamp + 90 days); // 3 months

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5)); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 2 deposit(5,12): FAILED");
        
        vm.stopPrank();


        vm.warp(block.timestamp + 360 days); // 1 year


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 200); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 200); 
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();
    }

    function test_example7() public {
        // Save initial balances
        uint256 depositor1BalanceBefore = proxy.rewardsToken().balanceOf(depositor1);
        uint256 depositor2BalanceBefore = proxy.rewardsToken().balanceOf(depositor2);
        uint256 depositor3BalanceBefore = proxy.rewardsToken().balanceOf(depositor3);
        
        // Deployer
        vm.startPrank(deployer);

        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "updateRewardsIssuancePerYear(uint256)", 
                600
            )
        );
        require(success, "Proxy - updateRewardsIssuancePerYear: FAILED");

        vm.stopPrank();

        // Depositor 1
        vm.startPrank(depositor1);
        
        (, bytes memory data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                6
            )
        );
        require(success, "Proxy - 1 deposit(5,6): FAILED");
        
        vm.stopPrank();

        vm.warp(block.timestamp + 90 days); // 3 months

        // Depositor 2
        vm.startPrank(depositor2);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 2 deposit(5,12): FAILED");
        
        vm.stopPrank();

        vm.warp(block.timestamp + 270 days); // 9 months

        // Depositor 3
        vm.startPrank(depositor3);
        
        (, data) = uniswapLPTokenAddress.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5));
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)", 
                5,
                12
            )
        );
        require(success, "Proxy - 3 deposit(5,12): FAILED");
        
        vm.stopPrank();


        vm.warp(block.timestamp + 360 days); // a year


        // Depositor 1
        vm.startPrank(depositor1);
        
        token.approve(address(proxy), 700);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                0
            )
        );
        require(success, "Proxy - claimRewards(0): FAILED");
        uint256 depositor1BalanceAfter = proxy.rewardsToken().balanceOf(depositor1);
        assertGt(depositor1BalanceAfter, depositor1BalanceBefore);
        
        vm.stopPrank();

        // Depositor 2
        vm.startPrank(depositor2);
        
        token.approve(address(proxy), 700);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                1
            )
        );
        require(success, "Proxy - claimRewards(1): FAILED");
        uint256 depositor2BalanceAfter = proxy.rewardsToken().balanceOf(depositor2);
        assertGt(depositor2BalanceAfter, depositor2BalanceBefore);

        vm.stopPrank();

        // Depositor 3
        vm.startPrank(depositor3);
        
        token.approve(address(proxy), 700);
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimRewards(uint256)", 
                2
            )
        );
        require(success, "Proxy - claimRewards(2): FAILED");
        uint256 depositor3BalanceAfter = proxy.rewardsToken().balanceOf(depositor3);
        assertGt(depositor3BalanceAfter, depositor3BalanceBefore);

        vm.stopPrank();
    }
}