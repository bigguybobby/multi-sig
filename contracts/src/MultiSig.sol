// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSig — Lightweight Multi-Signature Wallet
/// @notice Minimal multisig: propose, confirm, execute. Supports ETH + ERC20 + arbitrary calls.
contract MultiSig {
    // ─── Types ───────────────────────────────────────────────────────────

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 confirmations;
        bool executed;
    }

    // ─── State ───────────────────────────────────────────────────────────

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    // txId => owner => confirmed
    mapping(uint256 => mapping(address => bool)) public confirmed;

    // ─── Events ──────────────────────────────────────────────────────────

    event TxProposed(uint256 indexed txId, address indexed proposer, address to, uint256 value);
    event TxConfirmed(uint256 indexed txId, address indexed owner);
    event TxRevoked(uint256 indexed txId, address indexed owner);
    event TxExecuted(uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequirementChanged(uint256 required);

    // ─── Modifiers ───────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "not self");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx not found");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "already executed");
        _;
    }

    // ─── Constructor ─────────────────────────────────────────────────────

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "no owners");
        require(_required > 0 && _required <= _owners.length, "invalid required");

        for (uint256 i; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero address");
            require(!isOwner[o], "duplicate owner");
            isOwner[o] = true;
            owners.push(o);
        }
        required = _required;
    }

    // ─── Core Functions ──────────────────────────────────────────────────

    /// @notice Propose a new transaction
    function propose(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            confirmations: 0,
            executed: false
        }));
        emit TxProposed(txId, msg.sender, to, value);
    }

    /// @notice Confirm a pending transaction
    function confirm(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(!confirmed[txId][msg.sender], "already confirmed");
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations++;
        emit TxConfirmed(txId, msg.sender);
    }

    /// @notice Revoke a confirmation
    function revoke(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(confirmed[txId][msg.sender], "not confirmed");
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations--;
        emit TxRevoked(txId, msg.sender);
    }

    /// @notice Execute a transaction that has enough confirmations
    function execute(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage t = transactions[txId];
        require(t.confirmations >= required, "not enough confirmations");

        t.executed = true;
        (bool success,) = t.to.call{value: t.value}(t.data);
        require(success, "tx failed");

        emit TxExecuted(txId);
    }

    // ─── Governance (only via multisig itself) ───────────────────────────

    function addOwner(address owner) external onlySelf {
        require(owner != address(0), "zero address");
        require(!isOwner[owner], "already owner");
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "not owner");
        isOwner[owner] = false;

        for (uint256 i; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        if (required > owners.length) {
            required = owners.length;
        }
        emit OwnerRemoved(owner);
    }

    function changeRequirement(uint256 _required) external onlySelf {
        require(_required > 0 && _required <= owners.length, "invalid required");
        required = _required;
        emit RequirementChanged(_required);
    }

    // ─── View Functions ──────────────────────────────────────────────────

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 txId) external view returns (
        address to, uint256 value, bytes memory data, uint256 confirmations, bool executed
    ) {
        Transaction storage t = transactions[txId];
        return (t.to, t.value, t.data, t.confirmations, t.executed);
    }

    function isConfirmed(uint256 txId) external view returns (bool) {
        return transactions[txId].confirmations >= required;
    }

    /// @notice Accept ETH deposits
    receive() external payable {}
}
