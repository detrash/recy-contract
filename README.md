# deTrash smart contract

This project is bootstrapped with Hardhad, a development environment for Ethereum smart contracts.

## Development

1. Install dependencies

   ```bash
   yarn
   ```

2. Compile contracts

   ```bash
   yarn compile
   ```

3. Test contracts

   ```bash
   yarn test
   ```

## Deploy

1. Contracts can be deployed on any EVM network. To deploy contracts, you need to set up a `.env` file with the following variables

   ```bash
   HARDHAT_PRIVATE_KEY=0x...
   ```

2. Deploy contracts

   > [!NOTE]
   > Currently arguments for deployment are hardcoded in the scripts. You can change them in the scripts before deploying.

   | Script            | Description                 | Arguments                  |
   | ----------------- | --------------------------- | -------------------------- |
   | `deploy-all`      | Deploy all contracts        |                            |
   | `deploy-crecy`    | Deploy CRECY ERC20 contract | totalSupply, initialSupply |
   | `deploy-fcw`      | Deploy FCW ERC721 contract  |                            |
   | `deploy-timelock` | Deploy timelock contract    | crecy address              |

   | Network     | Description      |
   | ----------- | ---------------- |
   | `localhost` | Hardhat localnet |
   | `celo`      | CELO mainnet     |
   | `alfajores` | CELO testnet     |

   ```bash
   yarn hardhat run scripts/<script>.ts --network <network>
   ```
