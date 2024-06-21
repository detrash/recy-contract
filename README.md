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

1. Configure required environment variables in `.env` file

   ```bash
   cp .env.example .env
   ```

2. Deploy contracts, please check `scripts/deploy.ts` for more details

   ```bash
   yarn deploy:testnet
   ```
