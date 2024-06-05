# PSBTs: Constructing and Signing Multiple Inputs - SegWit V0

The purpose of this section is to construct a PSBT that spends multiple inputs and signs it.
We'll cover the following [BIP 174](https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki)
 roles:

- **Creator**: Creates a PSBT with multiple inputs and outputs.
- **Updater**: Adds Witness and SegWit V0 data to the PSBT.
- **Signer**: Signs the PSBT.
- **Finalizer**: Finalizes the PSBT.

The example will focus on spending two SegWit V0 inputs:

1. 20,000,000 satoshi UTXO, the first receiving ("external") address.
1. 10,000,000 satoshi UTXO, the first change ("internal") address.

We'll be sending this to two outputs:

1. 25,000,000 satoshis to a receivers' address.
1. 4,990,000 satoshis back to us as change.

The miner's fee will be 10,000 satoshis.

This is the `cargo` commands that you need to run this example:

```bash
cargo add bitcoin --features "std, rand-std"
```

First we'll need to import the following:

```rust
use std::collections::BTreeMap;
use std::str::FromStr;

use bitcoin::bip32::{ChildNumber, IntoDerivationPath, Fingerprint, Xpriv, Xpub};
use bitcoin::hashes::Hash;
use bitcoin::locktime::absolute;
use bitcoin::psbt::Input;
use bitcoin::secp256k1::{self, Message, Secp256k1, Signing};
use bitcoin::consensus;
use bitcoin::transaction::{self, OutPoint, TxIn, TxOut};
use bitcoin::{
    Address, Amount, EcdsaSighashType, Network, Psbt, ScriptBuf, Sequence,
    Txid, WPubkeyHash, Witness, XOnlyPublicKey,
};
```

Here is the logic behind these imports:

- `std::collections::BTreeMap` is used to store the key-value pairs of the Public Key PSBT input fields.
- `std::str::FromStr` is used to parse strings into Bitcoin primitives
- `bitcoin::bip32` is used to derive keys according to [BIP 32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- `bitcoin::hashes::Hash` is used to hash data
- `bitcoin::locktime::absolute` is used to create a locktime
- `bitcoin::psbt` is used to construct and manipulate PSBTs
- `bitcoin::secp256k1` is used to sign transactions
- `bitcoin::sighash` is used to create SegWit V0 sighashes
- `bitcoin::consensus` is used to serialize the final signed transaction to a raw transaction
- `bitcoin::transaction` and `bitcoin::{Address, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, Witness}` are used to construct transactions
- `bitcoin::WPubkeyHash` is used to construct SegWit V0 inputs

Next, we define the following constants:

```rust
# use bitcoin::Amount;
const XPRIV: &str = "xprv9tuogRdb5YTgcL3P8Waj7REqDuQx4sXcodQaWTtEVFEp6yRKh1CjrWfXChnhgHeLDuXxo2auDZegMiVMGGxwxcrb2PmiGyCngLxvLeGsZRq";
const BIP84_DERIVATION_PATH: &str = "m/84'/0'/0'";
const MASTER_FINGERPRINT: &str = "9680603f";
const DUMMY_UTXO_AMOUNT_INPUT_1: Amount = Amount::from_sat(20_000_000);
const DUMMY_UTXO_AMOUNT_INPUT_2: Amount = Amount::from_sat(10_000_000);
const SPEND_AMOUNT: Amount = Amount::from_sat(25_000_000);
const CHANGE_AMOUNT: Amount = Amount::from_sat(4_990_000); // 10_000 sat fee.
```

- `XPRIV` is the extended private key that will be used to derive the keys for the SegWit V0 inputs.
- `MASTER_FINGERPRINT` is the fingerprint of the master key.
- `BIP84_DERIVATION_PATH` is the derivation path for the BIP 84 key.
  Since this is a mainnet example, we are using the path `m/84'/0'/0'`.
- `DUMMY_UTXO_AMOUNT_INPUT_1` is the amount of the dummy UTXO we will be spending from the first input.
- `DUMMY_UTXO_AMOUNT_INPUT_2` is the amount of the dummy UTXO we will be spending from the second input.
- `SPEND_AMOUNT` is the amount we will be spending from the dummy UTXO related to the first input.
- `CHANGE_AMOUNT`[^change] is the amount we will be sending back to ourselves as change.

Before we can construct the transaction, we need to define some helper functions:

```rust
# use std::collections::BTreeMap;
# use std::str::FromStr;
#
# use bitcoin::bip32::{ChildNumber, IntoDerivationPath, Fingerprint, Xpriv, Xpub};
# use bitcoin::hashes::Hash;
# use bitcoin::secp256k1::{Secp256k1, Signing};
# use bitcoin::{Address, Amount, Network, OutPoint, Txid, TxOut};
#
# const BIP84_DERIVATION_PATH: &str = "m/84'/0'/0'";
# const DUMMY_UTXO_AMOUNT_INPUT_1: Amount = Amount::from_sat(20_000_000);
# const DUMMY_UTXO_AMOUNT_INPUT_2: Amount = Amount::from_sat(10_000_000);
fn get_external_address_xpriv<C: Signing>(
    secp: &Secp256k1<C>,
    master_xpriv: Xpriv,
    index: u32,
) -> Xpriv {
    let derivation_path =
        BIP84_DERIVATION_PATH.into_derivation_path().expect("valid derivation path");
    let child_xpriv = master_xpriv
        .derive_priv(secp, &derivation_path)
        .expect("valid child xpriv");
    let external_index = ChildNumber::from_normal_idx(0).unwrap();
    let idx = ChildNumber::from_normal_idx(index).expect("valid index number");

    child_xpriv
        .derive_priv(secp, &[external_index, idx])
        .expect("valid xpriv")
}

fn get_internal_address_xpriv<C: Signing>(
    secp: &Secp256k1<C>,
    master_xpriv: Xpriv,
    index: u32,
) -> Xpriv {
    let derivation_path =
        BIP84_DERIVATION_PATH.into_derivation_path().expect("valid derivation path");
    let child_xpriv = master_xpriv
        .derive_priv(secp, &derivation_path)
        .expect("valid child xpriv");
    let internal_index = ChildNumber::from_normal_idx(1).unwrap();
    let idx = ChildNumber::from_normal_idx(index).expect("valid index number");

    child_xpriv
        .derive_priv(secp, &[internal_index, idx])
        .expect("valid xpriv")
}

fn receivers_address() -> Address {
    Address::from_str("bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf")
        .expect("a valid address")
        .require_network(Network::Bitcoin)
        .expect("valid address for mainnet")
}

fn dummy_unspent_transaction_outputs() -> Vec<(OutPoint, TxOut)> {
    let script_pubkey_1 = Address::from_str("bc1qrwuu3ydv0jfza4a0ehtfd03m9l4vw3fy0hfm50")
        .expect("a valid address")
        .require_network(Network::Bitcoin)
        .expect("valid address for mainnet")
        .script_pubkey();

    let out_point_1 = OutPoint {
        txid: Txid::all_zeros(), // Obviously invalid.
        vout: 0,
    };

    let utxo_1 = TxOut {
        value: DUMMY_UTXO_AMOUNT_INPUT_1,
        script_pubkey: script_pubkey_1,
    };

    let script_pubkey_2 = Address::from_str("bc1qy7swwpejlw7a2rp774pa8rymh8tw3xvd2x2xkd")
        .expect("a valid address")
        .require_network(Network::Bitcoin)
        .expect("valid address for mainnet")
        .script_pubkey();

    let out_point_2 = OutPoint {
        txid: Txid::all_zeros(), // Obviously invalid.
        vout: 1,
    };

    let utxo_2 = TxOut {
        value: DUMMY_UTXO_AMOUNT_INPUT_2,
        script_pubkey: script_pubkey_2,
    };
    vec![(out_point_1, utxo_1), (out_point_2, utxo_2)]
}
```

`get_external_address_xpriv` and `get_internal_address_xpriv` generates the external and internal addresses extended private key,
given a master extended private key and an address index; respectively.
Note that these functions takes a `Secp256k1` that is
generic over the [`Signing`](https://docs.rs/secp256k1/0.29.0/secp256k1/trait.Signing.html) trait.
This is used to indicate that is an instance of `Secp256k1` and can be used for signing and other things.

`receivers_address` generates a receiver address.
In a real application this would be the address of the receiver.
We use the method `Address::from_str` to parse the string of addresses[^arbitrary_address] into an [`Address`](https://docs.rs/bitcoin/0.32.0/bitcoin/struct.Address.html).
Hence, it is necessary to import the `std::str::FromStr` trait.
This is an arbitrary, however valid, Bitcoin mainnet address.
Hence we use the `require_network` method to ensure that the address is valid for mainnet.

`dummy_unspent_transaction_outputs` generates a dummy unspent transaction output (UTXO).
This is a P2WPKH (`ScriptBuf::new_p2wpkh`) UTXO.

The UTXO has a dummy invalid transaction ID (`txid: Txid::all_zeros()`),
and any value of the `const DUMMY_UTXO_AMOUNT_N` that we defined earlier.
Note that the `vout` is set to `0` for the first UTXO and `1` for the second UTXO.
We are using the [`OutPoint`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.OutPoint.html) struct to represent the transaction output.
Finally, we return vector of tuples `(out_point, utxo)`.

Now we are ready for our main function that will create, update, and sign a PSBT;
while also extracting a transaction that spends the `p2wpkh`s unspent outputs:

```rust
# use std::collections::BTreeMap;
# use std::str::FromStr;
# 
# use bitcoin::bip32::{ChildNumber, IntoDerivationPath, Fingerprint, Xpriv, Xpub};
# use bitcoin::hashes::Hash;
# use bitcoin::locktime::absolute;
# use bitcoin::psbt::{Input, PsbtSighashType};
# use bitcoin::secp256k1::{Secp256k1, Signing};
# use bitcoin::{
#     consensus, transaction, Address, Amount, EcdsaSighashType, Network, OutPoint, Psbt, ScriptBuf, Sequence,
#     Transaction, TxIn, TxOut, Txid, WPubkeyHash, Witness,
# };
# 
# const XPRIV: &str = "xprv9tuogRdb5YTgcL3P8Waj7REqDuQx4sXcodQaWTtEVFEp6yRKh1CjrWfXChnhgHeLDuXxo2auDZegMiVMGGxwxcrb2PmiGyCngLxvLeGsZRq";
# const BIP84_DERIVATION_PATH: &str = "m/84'/0'/0'";
# const MASTER_FINGERPRINT: &str = "9680603f";
# const DUMMY_UTXO_AMOUNT_INPUT_1: Amount = Amount::from_sat(20_000_000);
# const DUMMY_UTXO_AMOUNT_INPUT_2: Amount = Amount::from_sat(10_000_000);
# const SPEND_AMOUNT: Amount = Amount::from_sat(25_000_000);
# const CHANGE_AMOUNT: Amount = Amount::from_sat(4_990_000); // 10_000 sat fee.
# 
# fn get_external_address_xpriv<C: Signing>(
#     secp: &Secp256k1<C>,
#     master_xpriv: Xpriv,
#     index: u32,
# ) -> Xpriv {
#     let derivation_path =
#         BIP84_DERIVATION_PATH.into_derivation_path().expect("valid derivation path");
#     let child_xpriv = master_xpriv
#         .derive_priv(secp, &derivation_path)
#         .expect("valid child xpriv");
#     let external_index = ChildNumber::from_normal_idx(0).unwrap();
#     let idx = ChildNumber::from_normal_idx(index).expect("valid index number");
# 
#     child_xpriv
#         .derive_priv(secp, &[external_index, idx])
#         .expect("valid xpriv")
# }
# 
# fn get_internal_address_xpriv<C: Signing>(
#     secp: &Secp256k1<C>,
#     master_xpriv: Xpriv,
#     index: u32,
# ) -> Xpriv {
#     let derivation_path =
#         BIP84_DERIVATION_PATH.into_derivation_path().expect("valid derivation path");
#     let child_xpriv = master_xpriv
#         .derive_priv(secp, &derivation_path)
#         .expect("valid child xpriv");
#     let internal_index = ChildNumber::from_normal_idx(1).unwrap();
#     let idx = ChildNumber::from_normal_idx(index).expect("valid index number");
# 
#     child_xpriv
#         .derive_priv(secp, &[internal_index, idx])
#         .expect("valid xpriv")
# }
# 
# fn receivers_address() -> Address {
#     Address::from_str("bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf")
#         .expect("a valid address")
#         .require_network(Network::Bitcoin)
#         .expect("valid address for mainnet")
# }
# 
# fn dummy_unspent_transaction_outputs() -> Vec<(OutPoint, TxOut)> {
#     let script_pubkey_1 = Address::from_str("bc1qrwuu3ydv0jfza4a0ehtfd03m9l4vw3fy0hfm50")
#         .expect("a valid address")
#         .require_network(Network::Bitcoin)
#         .expect("valid address for mainnet")
#         .script_pubkey();
# 
#     let out_point_1 = OutPoint {
#         txid: Txid::all_zeros(), // Obviously invalid.
#         vout: 0,
#     };
# 
#     let utxo_1 = TxOut {
#         value: DUMMY_UTXO_AMOUNT_INPUT_1,
#         script_pubkey: script_pubkey_1,
#     };
# 
#     let script_pubkey_2 = Address::from_str("bc1qy7swwpejlw7a2rp774pa8rymh8tw3xvd2x2xkd")
#         .expect("a valid address")
#         .require_network(Network::Bitcoin)
#         .expect("valid address for mainnet")
#         .script_pubkey();
# 
#     let out_point_2 = OutPoint {
#         txid: Txid::all_zeros(), // Obviously invalid.
#         vout: 1,
#     };
# 
#     let utxo_2 = TxOut {
#         value: DUMMY_UTXO_AMOUNT_INPUT_2,
#         script_pubkey: script_pubkey_2,
#     };
#     vec![(out_point_1, utxo_1), (out_point_2, utxo_2)]
# }
# 
fn main() {
    let secp = Secp256k1::new();

    // Get the individual xprivs we control. In a real application these would come from a stored secret.
    let master_xpriv = XPRIV.parse::<Xpriv>().expect("valid xpriv");
    let xpriv_input_1 = get_external_address_xpriv(&secp, master_xpriv, 0);
    let xpriv_input_2 = get_internal_address_xpriv(&secp, master_xpriv, 0);
    let xpriv_change = get_internal_address_xpriv(&secp, master_xpriv, 1);

    // Get the PKs
    let pk_input_1 = Xpub::from_priv(&secp, &xpriv_input_1).to_pub();
    let pk_input_2 = Xpub::from_priv(&secp, &xpriv_input_2).to_pub();
    let pk_inputs = [pk_input_1, pk_input_2];
    let pk_change = Xpub::from_priv(&secp, &xpriv_change).to_pub();

    // Get the Witness Public Key Hashes (WPKHs)
    let wpkhs: Vec<WPubkeyHash> = pk_inputs.iter().map(|pk| pk.wpubkey_hash()).collect();

    // Get the unspent outputs that are locked to the key above that we control.
    // In a real application these would come from the chain.
    let utxos: Vec<TxOut> = dummy_unspent_transaction_outputs()
        .into_iter()
        .map(|(_, utxo)| utxo)
        .collect();

    // Get the addresses to send to.
    let address = receivers_address();

    // The inputs for the transaction we are constructing.
    let inputs: Vec<TxIn> = dummy_unspent_transaction_outputs()
        .into_iter()
        .map(|(outpoint, _)| TxIn {
            previous_output: outpoint,
            script_sig: ScriptBuf::default(),
            sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
            witness: Witness::default(),
        })
        .collect();

    // The spend output is locked to a key controlled by the receiver.
    let spend = TxOut {
        value: SPEND_AMOUNT,
        script_pubkey: address.script_pubkey(),
    };

    // The change output is locked to a key controlled by us.
    let change = TxOut {
        value: CHANGE_AMOUNT,
        script_pubkey: ScriptBuf::new_p2wpkh(&pk_change.wpubkey_hash()), // Change comes back to us.
    };

    // The transaction we want to sign and broadcast.
    let unsigned_tx = Transaction {
        version: transaction::Version::TWO,  // Post BIP 68.
        lock_time: absolute::LockTime::ZERO, // Ignore the locktime.
        input: inputs,                       // Input is 0-indexed.
        output: vec![spend, change],         // Outputs, order does not matter.
    };

    // Now we'll start the PSBT workflow.
    // Step 1: Creator role; that creates,
    // and add inputs and outputs to the PSBT.
    let mut psbt = Psbt::from_unsigned_tx(unsigned_tx).expect("Could not create PSBT");

    // Step 2:Updater role; that adds additional
    // information to the PSBT.
    let ty = EcdsaSighashType::All.into();
    let derivation_paths = [
        "m/84'/0'/0'/0/0".into_derivation_path().expect("valid derivation path"), // First external address.
        "m/84'/0'/0'/1/0".into_derivation_path().expect("valid derivation path"), // First internal address.
    ];
    let mut bip32_derivations = Vec::new();
    for (idx, pk) in pk_inputs.iter().enumerate() {
        let mut map = BTreeMap::new();
        let fingerprint = Fingerprint::from_str(MASTER_FINGERPRINT).expect("valid fingerprint");
        map.insert(pk.0, (fingerprint, derivation_paths[idx].clone()));
        bip32_derivations.push(map);
    }
    psbt.inputs = vec![
        Input {
            witness_utxo: Some(utxos[0].clone()),
            redeem_script: Some(ScriptBuf::new_p2wpkh(&wpkhs[0])),
            bip32_derivation: bip32_derivations[0].clone(),
            sighash_type: Some(ty),
            ..Default::default()
        },
        Input {
            witness_utxo: Some(utxos[1].clone()),
            redeem_script: Some(ScriptBuf::new_p2wpkh(&wpkhs[1])),
            bip32_derivation: bip32_derivations[1].clone(),
            sighash_type: Some(ty),
            ..Default::default()
        },
    ];

    // Step 3: Signer role; that signs the PSBT.
    psbt.sign(&master_xpriv, &secp).expect("valid signature");

    // Step 4: Finalizer role; that finalizes the PSBT.
    println!("PSBT Inputs: {:#?}", psbt.inputs);
    let final_script_witness: Vec<_> = psbt
        .inputs
        .iter()
        .enumerate()
        .map(|(idx, input)| {
            let (_, sig) = input.partial_sigs.iter().next().expect("we have one sig");
            Witness::p2wpkh(sig, &pk_inputs[idx].0)
        })
        .collect();
    psbt.inputs.iter_mut().enumerate().for_each(|(idx, input)| {
        // Clear all the data fields as per the spec.
        input.final_script_witness = Some(final_script_witness[idx].clone());
        input.partial_sigs = BTreeMap::new();
        input.sighash_type = None;
        input.redeem_script = None;
        input.witness_script = None;
        input.bip32_derivation = BTreeMap::new();
    });

    // BOOM! Transaction signed and ready to broadcast.
    let signed_tx = psbt.extract_tx().expect("valid transaction");
    let serialized_signed_tx = consensus::encode::serialize_hex(&signed_tx);
    println!("Transaction Details: {:#?}", signed_tx);
    // check with:
    // bitcoin-cli decoderawtransaction <RAW_TX> true
    println!("Raw Transaction: {}", serialized_signed_tx);
}
```

Let's go over the main function code block by block.

`let secp = Secp256k1::new();` creates a new `Secp256k1` context with all capabilities.
Since we added the `rand-std` feature to our `Cargo.toml`,

Next, we get the individual extended private keys (xpriv) that we control.
These are:

- the master xpriv,
- the xprivs for inputs 1 and 2;
  these are done with the `get_external_address_xpriv` and `get_internal_address_xpriv` functions.
- the xpriv for the change output, also using the `get_internal_address_xpriv` function.

The inputs for the transaction we are constructing,
here named `utxos`,
are created with the `dummy_unspent_transaction_outputs` function.
`let address = receivers_address();` generates a receiver's address `address`.
All of these are helper functions that we defined earlier.

In `let input = TxIn {...}` we are instantiating the inputs for the transaction we are constructing
Inside the [`TxIn`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxIn.html) struct we are setting the following fields:

- `previous_output` is the outpoint of the dummy UTXO we are spending; it is a [`OutPoint`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.OutPoint.html) type.
- `script_sig` is the script code required to spend an output; it is a [`ScriptBuf`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   We are instantiating a new empty script with [`ScriptBuf::new()`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new).
- `sequence` is the sequence number; it is a [`Sequence`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Sequence.html) type.
   We are using the [`ENABLE_RBF_NO_LOCKTIME`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Sequence.html#associatedconstant.ENABLE_RBF_NO_LOCKTIME) constant.
- `witness` is the witness stack; it is a [`Witness`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html) type.
   We are using the [`default`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html#impl-Default) method to create an empty witness that will be filled in later after signing.
   This is possible because `Witness` implements the [`Default`](https://doc.rust-lang.org/std/default/trait.Default.html) trait.

In `let spend = TxOut {...}` we are instantiating the spend output.
Inside the [`TxOut`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxOut.html) struct we are setting the following fields:

- `value` is the amount we are spending; it is a [`u64`](https://doc.rust-lang.org/std/primitive.u64.html) type.
   We are using the `const SPEND_AMOUNT` that we defined earlier.
- `script_pubkey` is the script code required to spend a P2WPKH output; it is a [`ScriptBuf`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   We are using the [`script_pubkey`](https://docs.rs/bitcoin/0.32.0/bitcoin/address/struct.Address.html#method.script_pubkey) method to generate the script pubkey from the receivers address.
   This will lock the output to the receiver's address.

In `let change = TxOut {...}` we are instantiating the change output.
It is very similar to the `spend` output, but we are now using the `const CHANGE_AMOUNT` that we defined earlier[^spend].
This is done by setting the `script_pubkey` field to [`ScriptBuf::new_p2wpkh(...)`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new_p2wpkh),
which generates P2WPKH-type of script pubkey.

In `let unsigned_tx = Transaction {...}` we are instantiating the transaction we want to sign and broadcast using the [`Transaction`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Transaction.html) struct.
We set the following fields:

- `version` is the transaction version; it can be a [`i32`](https://doc.rust-lang.org/std/primitive.u32.html) type.
   However it is best to use the [`Version`](https://docs.rs/bitcoin/0.32.0/bitcoin/block/struct.Version.html) struct.
   We are using version `TWO` which means that [BIP 68](https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki) applies.
- `lock_time` is the transaction lock time;
   it is a [`LockTime`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html) enum.
   We are using the constant [`ZERO`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html#associatedconstant.ZERO)
   This will make the transaction valid immediately.
- `input` is the input vector; it is a [`Vec<TxIn>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `input` variable that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.
- `output` is the output vector; it is a [`Vec<TxOut>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `spend` and `change` variables that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.

Now we are ready to start our PSBT workflow.

The first step is the Creator role.
We create a PSBT from the unsigned transaction using the [`Psbt::from_unsigned_tx`](https://docs.rs/bitcoin/0.32.0/bitcoin/psbt/struct.Psbt.html#method.from_unsigned_tx) method.

Next, we move to the Updater role.
We add additional information to the PSBT.
This is done by setting the `psbt.inputs` field to a vector of [`Input`](https://docs.rs/bitcoin/0.32.0/bitcoin/psbt/struct.Input.html) structs.
In particular, we set the following fields:

- `witness_utxo` is the witness UTXO; it is an [`Option<TxOut>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
   We are using the `utxos` vector that we defined earlier.
- `redeem_script` is the redeem script; it is an [`Option<ScriptBuf>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
   We are using the [`ScriptBuf::new_p2wpkh`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new_p2wpkh) method to create a P2WPKH script.
- `bip32_derivation` is the BIP 32 derivation; it is a [`BTreeMap<Xpub, (Fingerprint, DerivationPath)>`](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html) type.
   We are using a vector of `BTreeMap`s.
- `sighash_type` is the sighash type; it is an [`Option<PsbtSighashType>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.

All the other fields are set to their default values using the [`Default::default()`](https://doc.rust-lang.org/std/default/trait.Default.html#tymethod.default) method.

The following step is the Signer role.
Here is were we sign the PSBT with the
[`sign`](https://docs.rs/bitcoin/0.32.0/bitcoin/psbt/struct.Psbt.html#method.sign) method.
This method takes the master extended private key and the `Secp256k1` context as arguments.
It attempts to create all the required signatures for this PSBT using the extended private key.

Finally, we move to the Finalizer role.
Here we finalize the PSBT, making it ready to be extracted into a signed transaction,
and if necessary, broadcasted to the Bitcoin network.
This is done by setting the following fields:

- `final_script_witness` is the final script witness; it is an [`Option<Witness>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
   We are using the `Witness::p2wpkh()` method to create a witness required to spend a P2WPKH output.
- `partial_sigs` is the partial signatures; it is a [`BTreeMap<XOnlyPublicKey, Vec<u8>>`](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html) type.
   We are using an empty map.
- `sighash_type` is the sighash type; it is an [`Option<PsbtSighashType>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
   We are using the `None` value.
- `redeem_script` is the redeem script; it is an [`Option<ScriptBuf>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
   We are using the `None` value.
- `witness_script` is the witness script; it is an [`Option<ScriptBuf>`](https://doc.rust-lang.org/std/option/enum.Option.html) type.
- `bip32_derivation` is the BIP 32 derivation; it is a [`BTreeMap<Xpub, (Fingerprint, DerivationPath)>`](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html) type.
   We are using an empty map.

Finally, we extract the signed transaction from the PSBT using the [`extract_tx`](https://docs.rs/bitcoin/0.32.0/bitcoin/psbt/struct.Psbt.html#method.extract_tx) method.

As the last step we print both the transaction details and the raw transaction
to the terminal using the [`println!`](https://doc.rust-lang.org/std/macro.println.html) macro.
This transaction is now ready to be broadcast to the Bitcoin network.

For anything in production, the step 4 (Finalizer) should be done with the
[`psbt::PsbtExt` from the `miniscript` crate](https://docs.rs/miniscript/11.0.0/miniscript/psbt/trait.PsbtExt.html) trait.
It provides a
[`.finalize_mut`](https://docs.rs/miniscript/11.0.0/miniscript/psbt/trait.PsbtExt.html#tymethod.finalize_mut)
to a [`Psbt`](https://docs.rs/bitcoin/0.32.0/bitcoin/psbt/struct.Psbt.html) object,
which takes in a mutable reference to `Psbt` and populates the `final_witness` and `final_scriptsig` for all inputs.

[^change]: Please note that the `CHANGE_AMOUNT` is not the same as the `DUMMY_UTXO_AMOUNT_INPUT_N`s minus the `SPEND_AMOUNT`.
           This is due to the fact that we need to pay a miner's fee for the transaction.

[^arbitrary_address]: this is an arbitrary mainnet addresses from block 805222.

[^spend]: And also we are locking the output to an address that we control:
          the `wpkh` public key hash that we generated earlier. 