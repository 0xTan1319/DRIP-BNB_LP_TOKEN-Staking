## Description

- A contract that mints Drip but according to a set inflation rate per year. The minting rate should be a variable so it can be modified if we change our mind from 5%.
- The contract also receives the 1% balance daily from the Treasury contract
- The contract can be interacted with with a dashboard

Tax Vault: Our plan is to change the tax vault address to a new contract, asking it to burn 90% and send 10% to the Treasury. In this case, no more taxes will be added to the current tax repository. 

And for tax treasuries, if possible, you can change those contracts to handle burns and treasury distributions. 

Alternatively, you can make Treasury a billable address and when Treasury bills, it will take 90% of your DRIP to deplete and 10% to increase your liquidity stash. 

Study the feasibility of the first option, if it works, fine, if not, study the feasibility of the second option. 

The second option removes issuing authority for that address, so it can only receive taxes and cannot issue new Drips.

The weekly lockout period can be up to 52 weeks.

## Hardhat Test

### CLI

`npm install`

Compile all `*.sol` files from one folder into the destination.

`npx hardhat compile`

You can test the smart contract with the test case.

`npx hardhat test`


## Hardhat Deploy

### Config
```js
// Replace this private key with your Sepolia account private key
// To export your private key from Coinbase Wallet, go to
// Settings > Developer Settings > Show private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Beware: NEVER put real Ether into testing accounts
const PRIVATE_KEY = "";
```
Write down `PRIVATE_KEY` in the `hardhat.config.js`

### CLI

To deploy the smart contract you can use this CLI:

```ps
npx hardhat run scripts/deploy.js --network <network-name>
```
