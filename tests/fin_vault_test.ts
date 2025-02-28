// [Previous imports and tests remain unchanged]

Clarinet.test({
  name: "Ensures withdrawal amount validation works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Try to withdraw 0 amount
    let block = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(0),
        types.principal(wallet1.address),
        types.none()
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(107));
  }
});

Clarinet.test({
  name: "Ensures withdrawal limit works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Set max withdrawal limit
    let setup = chain.mineBlock([
      Tx.contractCall('fin-vault', 'set-max-withdrawal-limit', [
        types.uint(1000000)
      ], deployer.address)
    ]);
    
    setup.receipts[0].result.expectOk();
    
    // Try to withdraw more than limit
    let block = chain.mineBlock([
      Tx.contractCall('fin-vault', 'request-withdrawal', [
        types.uint(2000000),
        types.principal(wallet1.address),
        types.none()
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(108));
  }
});

// [Rest of the tests remain unchanged]
