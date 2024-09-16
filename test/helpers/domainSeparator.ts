import { SignTypedDataVersion } from "@metamask/eth-sig-util";

const { TypedDataUtils } = require('@metamask/eth-sig-util')

const EIP712Domain = [
  { name: 'name', type: 'string' },
  { name: 'version', type: 'string' },
  { name: 'chainId', type: 'uint256' },
  { name: 'verifyingContract', type: 'address' },
];

export async function domainSeparator(name: string, version: string, chainId: bigint, verifyingContract: string) {
  return '0x' + TypedDataUtils.hashStruct(
    'EIP712Domain',
    { name, version, chainId, verifyingContract },
    { EIP712Domain },
    SignTypedDataVersion.V4
  ).toString('hex');
}