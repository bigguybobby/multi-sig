# Arbitrum Audit Program (AAP) — Application

## Project: MultiSig + Timelock Governance Suite

### Overview
A minimal, dependency-free governance toolkit for Arbitrum: a lightweight multi-signature wallet paired with a timelock controller. Designed for DAOs, treasuries, and protocol governance on Arbitrum.

### Why Arbitrum Needs This
- Most multisig solutions (Safe, etc.) are heavy, proxy-based, and hard to audit
- Our contracts are **single-file, zero-dependency** — easier to verify and trust
- Perfect for small-to-mid DAOs on Arbitrum who need governance without complexity
- MultiSig (proposer) → Timelock (delay) → Execution is the gold standard for governance security

### Technical Details

**MultiSig.sol** — Lightweight M-of-N multisig wallet
- Propose/confirm/revoke/execute transaction pattern
- Self-governance: add/remove owners, change threshold via multisig
- Supports ETH, ERC20, and arbitrary contract calls
- **37/37 tests, 100% line coverage, 94% branch coverage**
- Slither clean (0 critical/high/medium)

**Timelock.sol** — Governance timelock controller
- Queue/execute/cancel with configurable delay (1h–30d)
- Proposer/executor role separation
- 14-day grace period before expiry
- Self-governance: add/remove roles, change delay via timelock
- **45/45 tests, 100% line coverage, 93% branch coverage**
- Slither clean (0 critical/high/medium)

### Combined Stats
- **82 tests, 100% line/statement/function coverage**
- Zero external dependencies (pure Solidity)
- Static analysis clean on both contracts

### Team
- **Kacper** — Solidity/Foundry developer, smart contract security auditor
- Active on Immunefi bug bounties
- Prior security work: Pinto, Alchemix, Threshold, SSV
- Portfolio: 10 projects, 304 tests, 9 contracts — [GitHub](https://github.com/bigguybobby)

### Audit Ask
Requesting audit subsidy for professional audit of MultiSig + Timelock before mainnet deployment on Arbitrum. These are governance-critical contracts that will hold real funds.

### Repositories
- MultiSig: https://github.com/bigguybobby/multi-sig
- Timelock: https://github.com/bigguybobby/timelock

### Deployment Plan
1. Deploy to Arbitrum Sepolia testnet
2. Professional audit (via AAP subsidy)
3. Deploy to Arbitrum One mainnet
4. Open-source governance toolkit for Arbitrum ecosystem
