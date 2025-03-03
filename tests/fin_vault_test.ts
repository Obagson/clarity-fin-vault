// [Previous test content remains the same, adding new tests]

Clarinet.test({
  name: "Ensures proper balance tracking during withdrawals",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // First deposit some STX
    let deposit = chain.mineBlock([
      Tx.contractCall('fin-vault', 'deposit', [
        types.uint(1000000),
        types.none()
      ], wallet1.address)
    ]);
    
    deposit.receipts[0].result.expectOk();
    
    // Request withdrawal
    let withdrawal = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(500000),
        types.principal(wallet1.address),
        types.none()
      ], wallet1.address)
    ]);
    
    withdrawal.receipts[0].result.expectOk();
    
    // Check remaining balance
    let balance = chain.callReadOnlyFn(
      'fin-vault',
      'get-balance',
      [
        types.principal(wallet1.address),
        types.none()
      ],
      wallet1.address
    );
    
    balance.result.expectUint(500000);
  }
});
