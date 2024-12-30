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
| TimeLock			 | Celo    | [0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54](https://celoscan.io/address/0x2b7d8711e26e78218791b85edb1ff4eff1a8bf54)
| RecyCertificate    | Celo    | [0xd574e0605c20Fc683feDBDD01ce745fF2C1a6f40](https://celoscan.io/address/0xd574e0605c20fc683fedbdd01ce745ff2c1a6f40)

### Testnet

| Contract Name   | Address                                                                                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| CRecy           | [0x004c368A3fb45b0CD601e2203Fd2948D9d695a3b](https://alfajores.celoscan.io/address/0x004c368A3fb45b0CD601e2203Fd2948D9d695a3b) |
| FCWStatus       | [0xbf10E8d903bB4fcc705740d37d5668e2d5A6CBbC](https://alfajores.celoscan.io/address/0xbf10E8d903bB4fcc705740d37d5668e2d5A6CBbC) |
| RecyCertificate | [0x56A396a452f4F44412f089Efc3c4bF27aE6B5423](https://alfajores.celoscan.io/address/0x56A396a452f4F44412f089Efc3c4bF27aE6B5423) |
| TimeLock (deprecated)       | [~~0x64604b6564862d4544583943A108d948916CD2ec~~](https://alfajores.celoscan.io/address/0x64604b6564862d4544583943A108d948916CD2ec) |

# TimeLock Guide

This document describes how to interact with the Lock Contract in the cRecy ecosystem. This implementation considers the existence of the following contracts:

 - TimeLock: the contract responsible for keeping tokens during lock period and for emitting NFT certificates.
 - CRecy: the ERC-20 CRecy token
 - RecyCertificate: the NFT for each certificate
 - FCWStatus: the Friends of the Clean World contract

The CRecy and RecyCertificate addresses are passed as parameters during the TimeLock initialization. It supports the following roles:

- ADMIN_ROLE
- OPERATOR_ROLE
- PAUSER_ROLE

The current version of the contract is published on Celo Network in the following address: [0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54](https://celoscan.io/address/0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54).

## Certificate Creation

Every certificate submitted to the Lock Contract needs to be signed according to the [EIP-712](https://eips.ethereum.org/EIPS/eip-712). Each certificate should be an object with the following data and types:

    CertificateAuthorization: [
              { name: "institution", type: "bytes32" },
              { name: "tons", type: "uint8" },
              { name: "baseYear", type: "uint16" },
              { name: "baseMonth", type: "uint8" },
              { name: "timespan", type: "uint8" },
              { name: "signer", type: "address" },
              { name: "authorization", type: "bytes32" },
              { name: "deadline", type: "uint256" },
    ]

The first 5 fields are related to the certificate itself, while the last 3 are used to validate the signature on-chain, as follows:

-  `signer`: address of the account that will sign the certificate. Should have `ADMIN_ROLE` or `OPERATOR_ROLE` in the Lock Contract
- `authorization`: a unique control number in hex format for each authorization
- `deadline`: the date until that certificate can be presented to the Lock Contract

## Signing Process

Each signature should also contain the message, the `CertificateAuthorization` types object, and the following domain:

    {
          chainId: 31337,
          name: "GenericTypedMessage",
          version: "1",
          verifyingContract: "0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54"
     }

The signature process requires an account with `ADMIN_ROLE` or `OPERATOR_ROLE` to generate the signed message. It can be accomplished via a script or via a DApp, where signers can connect their EOA using solutions such as [Metamask](https://metamask.io), [Wallet Connect](https://walletconnect.network/) or any other equivalent solution.

Here, we provide an example using [Ethers.js](https://docs.ethers.org/v6/) with a randomly created account:

    import moment from "moment";
    import { HDNodeWallet } from "@ethersproject/wallet"
    import { fromRpcSig } from 'ethereumjs-util';
    import { doLock } from "./lockUtils.js"
    
    certTypedMessage = {
       domain: {
         chainId: 31337,
         name: "GenericTypedMessage",
         version: "1",
         verifyingContract: "0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54"
       },
       message: {
         institution: ethers.encodeBytes32String("Acme Inc."),
         tons: '3',
         baseYear: '2024',
         baseMonth: '1',
         timespan: '12',
         signer: admin.address,
         authorization: `0x1`,
         deadline: moment().add(1, 'day').format('X')
       },
       types: {
         CertificateAuthorization: [
           { name: "institution", type: "bytes32" },
           { name: "tons", type: "uint8" },
           { name: "baseYear", type: "uint16" },
           { name: "baseMonth", type: "uint8" },
           { name: "timespan", type: "uint8" },
           { name: "signer", type: "address" },
           { name: "authorization", type: "bytes32" },
           { name: "deadline", type: "uint256" },
         ],
       },
     };
     const wallet = HDNodeWallet.createRandom();
     const amount = 100; // A value to be defined
     wallet.signTypedData(
	     certTypedMessage.domain,
	     certTypedMessage.types,
	     certTypedMessage.message
     ).then( async (signedCertificate) => {
	     const rsvSignedCertificate = fromRpcSig(signedCertificate);
	     await doLock(amount, certTypedMessage.message, rsvSignedCertificate);
     });

## Locking a certificate

To lock a certificate in the Lock Contract, it is necessary to meet the following conditions:

- Having a signed, not used, not expired, certificate `{ r, s, v}` components
- Approval from certificate receiving account for the Lock Contract to move at least the amount of CRecy tokens to be locked on their behalf

Any account can call a lock procedure in the Lock Contract passing the lock amount, the certificate data and the signature. Ahead, we provide the `lockUtils.js` script that exports a function to lock an amount in CRecy and a certificate in the contract.

    import { Contract } from  "@ethersproject/contract";
    import lockContractAbi from "./lockContractAbi.json";
	
	export const doLock (amount, certificate, signature) => {
		const contract = new Contract("0x2B7D8711E26E78218791B85EdB1ff4EFf1A8BF54", lockContractAbi);

		contract.lock(amount, certificate, signature);
	}

