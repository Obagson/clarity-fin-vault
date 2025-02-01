import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures STX vault deposit works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit-stx', [
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Check balance
    let balanceBlock = chain.mineBlock([
      Tx.contractCall('fin-vault', 'get-balance', [
        types.principal(wallet1.address),
        types.none()
      ], wallet1.address)
    ]);
    
    assertEquals(balanceBlock.receipts[0].result.expectOk(), types.uint(1000000));
  }
});

Clarinet.test({
  name: "Ensures token deposit and withdrawal flow works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const tokenContract = deployer.address + '.test-token';
    
    // Setup: Add authorized signers, whitelist addresses and token
    let setup = chain.mineBlock([
      Tx.contractCall('fin-vault', 'add-authorized-signer', [
        types.principal(wallet1.address)
      ], deployer.address),
      Tx.contractCall('fin-vault', 'add-authorized-signer', [
        types.principal(wallet2.address)
      ], deployer.address),
      Tx.contractCall('fin-vault', 'add-whitelisted-address', [
        types.principal(wallet1.address)
      ], deployer.address),
      Tx.contractCall('fin-vault', 'add-whitelisted-token', [
        types.principal(tokenContract)
      ], deployer.address)
    ]);
    
    setup.receipts.map(receipt => receipt.result.expectOk());
    
    // Deposit tokens
    let deposit = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit-token', [
        types.principal(tokenContract),
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    deposit.receipts[0].result.expectOk();
    
    // Request withdrawal
    let request = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(500000),
        types.principal(wallet1.address),
        types.some(types.principal(tokenContract))
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
  name: "Ensures non-whitelisted token deposits are rejected",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const invalidToken = deployer.address + '.invalid-token';
    
    let deposit = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit-token', [
        types.principal(invalidToken),
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    deposit.receipts[0].result.expectErr(types.uint(106));
  }
});
