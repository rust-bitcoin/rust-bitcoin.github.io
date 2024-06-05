# Working with PSBTs

The Partially Signed Bitcoin Transaction (PSBT) format specifies an encoding for partially signed transactions.
PSBTs are used in the context of multisignature wallets, hardware wallets,
and other use cases where multiple parties need to collaborate to sign a transaction.

PSBT version 0 is defined in [BIP 174](https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki).
It specifies 6 different roles that a party can play in the PSBT workflow:

- **Creator**: Creates the PSBT and adds inputs and outputs.
- **Updater**: Adds additional information to the PSBT,
  such as `redeemScript`, `witnessScript`, and BIP32 derivation paths.
- **Signer**: Signs the PSBT, either all inputs or a subset of them.
- **Combiner**: Combines multiple PSBTs into a single PSBT.
- **Finalizer**: Finalizes the PSBT,
  adding any information necessary to complete the transaction.
- **Extractor**: Extracts the finalized transaction from the PSBT.

Note that multiple roles can be handled by a single entity
but each role is specialized in what it should be capable of doing.

We provide the following examples:

- [Constructing and Signing Multiple Inputs - SegWit V0](psbt/multiple_inputs_segwit-v0.md)
- [Constructing and Signing Multiple Inputs - Taproot](psbt/multiple_inputs_taproot.md)

For extra information, see the [Bitcoin Optech article on PSBTs](https://bitcoinops.org/en/topics/psbt/).