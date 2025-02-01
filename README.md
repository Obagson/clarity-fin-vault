# FinVault

A secure smart contract vault for managing crypto assets on the Stacks blockchain. The vault provides:

- Secure storage of STX and SIP-010 tokens
- Time-locked withdrawals
- Multi-signature authorization
- Emergency lockdown capabilities
- Whitelisted withdrawal addresses
- Token whitelisting for supported assets

## Features

- Deposit STX and SIP-010 tokens into the vault
- Configure time locks for withdrawals
- Set up multiple authorized signers
- Emergency freeze functionality
- Whitelist management for withdrawal addresses
- Token whitelisting for supported assets
- Full withdrawal history tracking

## Security

The vault implements multiple security features including:
- Multi-signature requirements for large withdrawals 
- Time delays between withdrawal requests and execution
- Emergency freeze capability
- Whitelisting of withdrawal addresses
- Token whitelisting to prevent unauthorized token deposits

## Token Support

The vault now supports any SIP-010 compliant token. Features include:
- Whitelisting of supported tokens by contract owner
- Separate balance tracking for each token
- Token-specific deposit and withdrawal functions
- Full integration with existing security features

## Usage

See the contract documentation for details on interacting with the vault.
