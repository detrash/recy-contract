# RECY Network smart contract

[![CI](https://github.com/detrash/detrash-contract/actions/workflows/ci.yml/badge.svg)](https://github.com/detrash/detrash-contract/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/detrash/detrash-contract/graph/badge.svg?token=MDYJB5LOWI)](https://codecov.io/gh/detrash/detrash-contract)

This project is bootstrapped with Hardhat, a development environment for Ethereum smart contracts.

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

Verify smart contract codes on explorer

```bash
yarn hardhat verify --network <network> <address>
```

## Deployed Addresses

| Contract Name      | Network | Address                                                                                                                          |
| ------------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| cRECY              | Celo    | [0x34C11A932853Ae24E845Ad4B633E3cEf91afE583](https://explorer.celo.org/mainnet/token/0x34C11A932853Ae24E845Ad4B633E3cEf91afE583) |
| DeTrashCertificate | Polygon | [0xbc68c4ec4182e1d2c73b5e58bd92be9871db2230](https://polygonscan.com/token/0xbc68c4ec4182e1d2c73b5e58bd92be9871db2230)           |

### Testnet

| Contract Name   | Address                                                                                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| CRecy           | [0x004c368A3fb45b0CD601e2203Fd2948D9d695a3b](https://alfajores.celoscan.io/address/0x004c368A3fb45b0CD601e2203Fd2948D9d695a3b) |
| FCWStatus       | [0xbf10E8d903bB4fcc705740d37d5668e2d5A6CBbC](https://alfajores.celoscan.io/address/0xbf10E8d903bB4fcc705740d37d5668e2d5A6CBbC) |
| RecyCertificate | [0x56A396a452f4F44412f089Efc3c4bF27aE6B5423](https://alfajores.celoscan.io/address/0x56A396a452f4F44412f089Efc3c4bF27aE6B5423) |
| TimeLock        | [0x64604b6564862d4544583943A108d948916CD2ec](https://alfajores.celoscan.io/address/0x64604b6564862d4544583943A108d948916CD2ec) |
