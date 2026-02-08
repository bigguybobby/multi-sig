// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract Receiver {
    uint256 public value;
    function setValue(uint256 v) external payable { value = v; }
    receive() external payable {}
}

contract MultiSigTest is Test {
    MultiSig ms;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    Receiver receiver;

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = carol;

        ms = new MultiSig(owners, 2);
        receiver = new Receiver();
        vm.deal(address(ms), 10 ether);
    }

    // ─── Constructor ─────────────────────────────────────────────────

    function test_constructor() public view {
        assertEq(ms.required(), 2);
        assertTrue(ms.isOwner(alice));
        assertTrue(ms.isOwner(bob));
        assertTrue(ms.isOwner(carol));
        address[] memory owners = ms.getOwners();
        assertEq(owners.length, 3);
    }

    function test_constructor_noOwners() public {
        address[] memory owners = new address[](0);
        vm.expectRevert("no owners");
        new MultiSig(owners, 1);
    }

    function test_constructor_invalidRequired_zero() public {
        address[] memory owners = new address[](1);
        owners[0] = alice;
        vm.expectRevert("invalid required");
        new MultiSig(owners, 0);
    }

    function test_constructor_invalidRequired_tooHigh() public {
        address[] memory owners = new address[](1);
        owners[0] = alice;
        vm.expectRevert("invalid required");
        new MultiSig(owners, 2);
    }

    function test_constructor_zeroAddress() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = address(0);
        vm.expectRevert("zero address");
        new MultiSig(owners, 1);
    }

    function test_constructor_duplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = alice;
        vm.expectRevert("duplicate owner");
        new MultiSig(owners, 1);
    }

    // ─── Propose ─────────────────────────────────────────────────────

    function test_propose() public {
        vm.prank(alice);
        uint256 txId = ms.propose(address(receiver), 1 ether, "");

        assertEq(txId, 0);
        assertEq(ms.getTransactionCount(), 1);

        (address to, uint256 value, , uint256 confs, bool exec) = ms.getTransaction(0);
        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(confs, 0);
        assertFalse(exec);
    }

    function test_propose_notOwner() public {
        vm.prank(makeAddr("rando"));
        vm.expectRevert("not owner");
        ms.propose(address(receiver), 1 ether, "");
    }

    // ─── Confirm ─────────────────────────────────────────────────────

    function test_confirm() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);

        (,,, uint256 confs,) = ms.getTransaction(0);
        assertEq(confs, 1);
        assertTrue(ms.confirmed(0, alice));
    }

    function test_confirm_alreadyConfirmed() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.startPrank(alice);
        ms.confirm(0);
        vm.expectRevert("already confirmed");
        ms.confirm(0);
        vm.stopPrank();
    }

    function test_confirm_notOwner() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(makeAddr("rando"));
        vm.expectRevert("not owner");
        ms.confirm(0);
    }

    function test_confirm_txNotFound() public {
        vm.prank(alice);
        vm.expectRevert("tx not found");
        ms.confirm(99);
    }

    // ─── Revoke ──────────────────────────────────────────────────────

    function test_revoke() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.startPrank(alice);
        ms.confirm(0);
        ms.revoke(0);
        vm.stopPrank();

        (,,, uint256 confs,) = ms.getTransaction(0);
        assertEq(confs, 0);
        assertFalse(ms.confirmed(0, alice));
    }

    function test_revoke_notConfirmed() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        vm.expectRevert("not confirmed");
        ms.revoke(0);
    }

    // ─── Execute ─────────────────────────────────────────────────────

    function test_execute_ethTransfer() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        assertTrue(ms.isConfirmed(0));

        vm.prank(alice);
        ms.execute(0);

        (,,,, bool exec) = ms.getTransaction(0);
        assertTrue(exec);
        assertEq(address(receiver).balance, 1 ether);
    }

    function test_execute_contractCall() public {
        bytes memory data = abi.encodeWithSelector(Receiver.setValue.selector, 42);
        vm.prank(alice);
        ms.propose(address(receiver), 0, data);

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(carol);
        ms.execute(0);

        assertEq(receiver.value(), 42);
    }

    function test_execute_notEnoughConfirmations() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);
        // only 1 of 2 required

        assertFalse(ms.isConfirmed(0));

        vm.prank(alice);
        vm.expectRevert("not enough confirmations");
        ms.execute(0);
    }

    function test_execute_alreadyExecuted() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(alice);
        ms.execute(0);

        vm.prank(alice);
        vm.expectRevert("already executed");
        ms.execute(0);
    }

    function test_execute_txFailed() public {
        // Send ETH to an address that can't receive
        vm.prank(alice);
        ms.propose(address(ms), 100 ether, ""); // ms can't receive 100 ETH from itself

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(alice);
        vm.expectRevert("tx failed");
        ms.execute(0);
    }

    function test_confirm_alreadyExecuted() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(alice);
        ms.execute(0);

        vm.prank(carol);
        vm.expectRevert("already executed");
        ms.confirm(0);
    }

    function test_revoke_alreadyExecuted() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");

        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(alice);
        ms.execute(0);

        vm.prank(alice);
        vm.expectRevert("already executed");
        ms.revoke(0);
    }

    // ─── Governance ──────────────────────────────────────────────────

    function test_addOwner_viaSelf() public {
        address dave = makeAddr("dave");
        bytes memory data = abi.encodeWithSelector(MultiSig.addOwner.selector, dave);

        vm.prank(alice);
        ms.propose(address(ms), 0, data);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        ms.execute(0);

        assertTrue(ms.isOwner(dave));
        address[] memory owners = ms.getOwners();
        assertEq(owners.length, 4);
    }

    function test_addOwner_notSelf() public {
        vm.prank(alice);
        vm.expectRevert("not self");
        ms.addOwner(makeAddr("dave"));
    }

    function test_addOwner_zeroAddress() public {
        bytes memory data = abi.encodeWithSelector(MultiSig.addOwner.selector, address(0));
        vm.prank(alice);
        ms.propose(address(ms), 0, data);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        vm.expectRevert("tx failed");
        ms.execute(0);
    }

    function test_addOwner_alreadyOwner() public {
        bytes memory data = abi.encodeWithSelector(MultiSig.addOwner.selector, alice);
        vm.prank(alice);
        ms.propose(address(ms), 0, data);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        vm.expectRevert("tx failed");
        ms.execute(0);
    }

    function test_removeOwner_viaSelf() public {
        bytes memory data = abi.encodeWithSelector(MultiSig.removeOwner.selector, carol);
        vm.prank(alice);
        ms.propose(address(ms), 0, data);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        ms.execute(0);

        assertFalse(ms.isOwner(carol));
        address[] memory owners = ms.getOwners();
        assertEq(owners.length, 2);
        assertEq(ms.required(), 2);
    }

    function test_removeOwner_adjustsRequired() public {
        // Remove 2 owners, required should adjust from 2 to 1
        bytes memory data1 = abi.encodeWithSelector(MultiSig.removeOwner.selector, carol);
        vm.prank(alice);
        ms.propose(address(ms), 0, data1);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        ms.execute(0);

        bytes memory data2 = abi.encodeWithSelector(MultiSig.removeOwner.selector, bob);
        vm.prank(alice);
        ms.propose(address(ms), 0, data2);
        vm.prank(alice);
        ms.confirm(1);
        vm.prank(bob);
        ms.confirm(1);
        vm.prank(alice);
        ms.execute(1);

        assertEq(ms.required(), 1);
        address[] memory owners = ms.getOwners();
        assertEq(owners.length, 1);
    }

    function test_removeOwner_notSelf() public {
        vm.prank(alice);
        vm.expectRevert("not self");
        ms.removeOwner(carol);
    }

    function test_changeRequirement_viaSelf() public {
        bytes memory data = abi.encodeWithSelector(MultiSig.changeRequirement.selector, 3);
        vm.prank(alice);
        ms.propose(address(ms), 0, data);
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);
        vm.prank(alice);
        ms.execute(0);

        assertEq(ms.required(), 3);
    }

    function test_changeRequirement_notSelf() public {
        vm.prank(alice);
        vm.expectRevert("not self");
        ms.changeRequirement(1);
    }

    // ─── View Functions ──────────────────────────────────────────────

    function test_getTransactionCount() public {
        assertEq(ms.getTransactionCount(), 0);

        vm.startPrank(alice);
        ms.propose(address(receiver), 1 ether, "");
        ms.propose(address(receiver), 2 ether, "");
        vm.stopPrank();

        assertEq(ms.getTransactionCount(), 2);
    }

    function test_receive() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        (bool ok,) = address(ms).call{value: 5 ether}("");
        assertTrue(ok);
        assertEq(address(ms).balance, 15 ether);
    }

    function test_multipleProposals() public {
        vm.startPrank(alice);
        uint256 id0 = ms.propose(address(receiver), 1 ether, "");
        uint256 id1 = ms.propose(address(receiver), 2 ether, "");
        vm.stopPrank();

        assertEq(id0, 0);
        assertEq(id1, 1);
    }

    function test_execute_notOwner() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");
        vm.prank(alice);
        ms.confirm(0);
        vm.prank(bob);
        ms.confirm(0);

        vm.prank(makeAddr("rando"));
        vm.expectRevert("not owner");
        ms.execute(0);
    }

    function test_revoke_notOwner() public {
        vm.prank(alice);
        ms.propose(address(receiver), 1 ether, "");
        vm.prank(alice);
        ms.confirm(0);

        vm.prank(makeAddr("rando"));
        vm.expectRevert("not owner");
        ms.revoke(0);
    }

    function test_execute_txNotFound() public {
        vm.prank(alice);
        vm.expectRevert("tx not found");
        ms.execute(99);
    }

    function test_revoke_txNotFound() public {
        vm.prank(alice);
        vm.expectRevert("tx not found");
        ms.revoke(99);
    }
}
