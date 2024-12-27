import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures vault deposit works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit', [
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Check balance
    let balanceBlock = chain.mineBlock([
      Tx.contractCall('fin-vault', 'get-balance', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    assertEquals(balanceBlock.receipts[0].result.expectOk(), types.uint(1000000));
  }
});

Clarinet.test({
  name: "Ensures withdrawal flow works with proper authorization",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Setup: Add authorized signers and whitelist
    let setup = chain.mineBlock([
      Tx.contractCall('fin-vault', 'add-authorized-signer', [
        types.principal(wallet1.address)
      ], deployer.address),
      Tx.contractCall('fin-vault', 'add-authorized-signer', [
        types.principal(wallet2.address)
      ], deployer.address),
      Tx.contractCall('fin-vault', 'add-whitelisted-address', [
        types.principal(wallet1.address)
      ], deployer.address)
    ]);
    
    setup.receipts.map(receipt => receipt.result.expectOk());
    
    // Deposit
    let deposit = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit', [
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    // Request withdrawal
    let request = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(500000),
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    const withdrawalId = request.receipts[0].result.expectOk();
    
    // Sign withdrawal
    let signatures = chain.mineBlock([
      Tx.contractCall('fin-vault', 'sign-withdrawal', [
        withdrawalId
      ], wallet1.address),
      Tx.contractCall('fin-vault', 'sign-withdrawal', [
        withdrawalId
      ], wallet2.address)
    ]);
    
    signatures.receipts.map(receipt => receipt.result.expectOk());
    
    // Mine blocks to pass time lock
    chain.mineEmptyBlockUntil(chain.blockHeight + 144);
    
    // Execute withdrawal
    let execution = chain.mineBlock([
      Tx.contractCall('fin-vault', 'execute-withdrawal', [
        withdrawalId
      ], wallet1.address)
    ]);
    
    execution.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Ensures emergency freeze works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Activate emergency freeze
    let freeze = chain.mineBlock([
      Tx.contractCall('fin-vault', 'emergency-freeze', [], deployer.address)
    ]);
    
    freeze.receipts[0].result.expectOk();
    
    // Try withdrawal during freeze
    let withdrawal = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(1000),
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    
    withdrawal.receipts[0].result.expectErr(types.uint(101));
  }
});