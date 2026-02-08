# 🔐 MultiSig — Lightweight Multi-Signature Wallet

> Minimal, auditable multisig: propose, confirm, execute. Supports ETH + ERC20 + arbitrary calls.

## Features

- **Propose** — any owner can propose a transaction
- **Confirm** — owners confirm (revoke anytime before execution)
- **Execute** — once threshold met, any owner executes
- **Governance** — add/remove owners, change threshold (via multisig itself)
- **Flexible** — supports ETH transfers, ERC20, and arbitrary contract calls

## Stats

- ✅ **37/37 tests passing**
- ✅ **100% line, statement, function coverage, 94% branch**
- ✅ Slither clean
- 📄 MIT License

## Quick Start

```solidity
// Deploy with 3 owners, 2-of-3 required
address[] memory owners = new address[](3);
owners[0] = alice; owners[1] = bob; owners[2] = carol;
MultiSig ms = new MultiSig(owners, 2);

// Propose ETH transfer
uint256 txId = ms.propose(recipient, 1 ether, "");

// 2 owners confirm
ms.confirm(txId); // alice
ms.confirm(txId); // bob

// Execute
ms.execute(txId);
```

## Tech Stack

- Solidity 0.8.20, Foundry
- No external dependencies (pure Solidity)

## License

MIT
