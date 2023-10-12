# Constructing and Signing Transactions - SegWit V0

In this section, we will construct a [SegWit V0 transaction](https://bitcoinops.org/en/topics/segregated-witness/).
This is the most common type of transaction on the Bitcoin network today[^today].

This is the `cargo` commands that you need to run this example:

```bash
cargo add bitcoin --features "std, rand-std"
```

First we'll need to import the following:

```rust
use std::str::FromStr;

use bitcoin::hashes::Hash;
use bitcoin::locktime::absolute;
use bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing};
use bitcoin::sighash::{EcdsaSighashType, SighashCache};
use bitcoin::{
    Address, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, WPubkeyHash,
    Witness,
};
```

Here is the logic behind these imports:

- `std::str::FromStr` is used to parse strings into Bitcoin primitives
- `bitcoin::hashes::Hash` is used to hash data
- `bitcoin::locktime::absolute` is used to create a locktime
- `bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing}` is used to sign transactions
- `bitcoin::sighash::{EcdsaSighashType, SighashCache}` is used to create sighashes
- `bitcoin::{Address, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, WPubkeyHash, Witness}` is used to construct transactions

Next, we define the following constants:

```rust
const DUMMY_UTXO_AMOUNT: u64 = 20_000_000;
const SPEND_AMOUNT: u64 = 5_000_000;
const CHANGE_AMOUNT: u64 = 14_999_000; // 1000 sat fee.
```

- `DUMMY_UTXO_AMOUNT` is the amount of the dummy UTXO we will be spending
- `SPEND_AMOUNT` is the amount we will be spending from the dummy UTXO
- `CHANGE_AMOUNT`[^change] is the amount we will be sending back to ourselves as change

Before we can construct the transaction, we need to define some helper functions[^expect]:

```rust
# use bitcoin::secp256k1::{rand, Secp256k1, SecretKey, Signing};
# use bitcoin::WPubkeyHash;
fn senders_keys<C: Signing>(secp: &Secp256k1<C>) -> (SecretKey, WPubkeyHash) {
    let sk = SecretKey::new(&mut rand::thread_rng());
    let pk = bitcoin::PublicKey::new(sk.public_key(secp));
    let wpkh = pk.wpubkey_hash().expect("key is compressed");

    (sk, wpkh)
}
```

`senders_keys` generates a random private key and derives the corresponding public key hash.
This will be useful to mock a sender.
In a real application these would be actual secrets[^secp].
We use the `SecretKey::new` method to generate a random private key `sk`.
We then use the `PublicKey::new` method to derive the corresponding public key `pk`.
Finally, we use the `PublicKey::wpubkey_hash` method to derive the corresponding public key hash `wpkh`.
Note that `senders_keys` is generic over the [`Signing`](https://docs.rs/secp256k1/0.27.0/secp256k1/trait.Signing.html) trait.
This is used to indicate that is an instance of `Secp256k1` and can be used for signing.
We conclude returning the private key `sk` and the public key hash `wpkh` as a tuple.

```rust
# use std::str::FromStr;
# use bitcoin::{Address, Network};
fn receivers_address() -> Address {
    Address::from_str("bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf")
        .expect("a valid address")
        .require_network(Network::Bitcoin)
        .expect("valid address for mainnet")
}
```

`receivers_address` generates a receiver address.
In a real application this would be the address of the receiver.
We use the method `Address::from_str` to parse the string `"bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf"` into an address.
Hence, it is necessary to import the `std::str::FromStr` trait.
Note that `bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf` is a [Bech32](https://bitcoinops.org/en/topics/bech32/) address.
This is an arbitrary, however valid, Bitcoin mainnet address.
Hence we use the `require_network` method to ensure that the address is valid for mainnet.

```rust
# use bitcoin::{OutPoint, ScriptBuf, TxOut, Txid, WPubkeyHash};
# use bitcoin::hashes::Hash;
# const DUMMY_UTXO_AMOUNT: u64 = 20_000_000;
fn dummy_unspent_transaction_output(wpkh: &WPubkeyHash) -> (OutPoint, TxOut) {
    let script_pubkey = ScriptBuf::new_v0_p2wpkh(wpkh);

    let out_point = OutPoint {
        txid: Txid::all_zeros(), // Obviously invalid.
        vout: 0,
    };

    let utxo = TxOut {
        value: DUMMY_UTXO_AMOUNT,
        script_pubkey,
    };

    (out_point, utxo)
}
```

`dummy_unspent_transaction_output` generates a dummy unspent transaction output (UTXO).
This is a SegWit V0 P2WPKH (`ScriptBuf::new_v0_p2wpkh`) UTXO with a dummy invalid transaction ID (`txid: Txid::all_zeros()`),
and a value of the `const DUMMY_UTXO_AMOUNT` that we defined earlier.
We are using the [`OutPoint`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.OutPoint.html) struct to represent the transaction output.
Finally, we return the tuple `(out_point, utxo)`.

Now we are ready for our main function that will sign a transaction that spends a `p2wpkh` unspent output:

```rust
# use std::str::FromStr;
#
# use bitcoin::hashes::Hash;
# use bitcoin::locktime::absolute;
# use bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing};
# use bitcoin::sighash::{EcdsaSighashType, SighashCache};
# use bitcoin::{
#     Address, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, WPubkeyHash,
#     Witness,
# };
#
# const DUMMY_UTXO_AMOUNT: u64 = 20_000_000;
# const SPEND_AMOUNT: u64 = 5_000_000;
# const CHANGE_AMOUNT: u64 = 14_999_000; // 1000 sat fee.
#
# fn senders_keys<C: Signing>(secp: &Secp256k1<C>) -> (SecretKey, WPubkeyHash) {
#     let sk = SecretKey::new(&mut rand::thread_rng());
#     let pk = bitcoin::PublicKey::new(sk.public_key(secp));
#     let wpkh = pk.wpubkey_hash().expect("key is compressed");
# 
#     (sk, wpkh)
# }
# 
# 
# fn receivers_address() -> Address {
#     Address::from_str("bc1q7cyrfmck2ffu2ud3rn5l5a8yv6f0chkp0zpemf")
#         .expect("a valid address")
#         .require_network(Network::Bitcoin)
#         .expect("valid address for mainnet")
# }
# 
# fn dummy_unspent_transaction_output(wpkh: &WPubkeyHash) -> (OutPoint, TxOut) {
#     let script_pubkey = ScriptBuf::new_v0_p2wpkh(wpkh);
# 
#     let out_point = OutPoint {
#         txid: Txid::all_zeros(), // Obviously invalid.
#         vout: 0,
#     };
# 
#     let utxo = TxOut {
#         value: DUMMY_UTXO_AMOUNT,
#         script_pubkey,
#     };
# 
#     (out_point, utxo)
# }

fn main() {
    let secp = Secp256k1::new();
    let (sk, wpkh) = senders_keys(&secp);
    let address = receivers_address();
    let (dummy_out_point, dummy_utxo) = dummy_unspent_transaction_output(&wpkh);

    // The script code required to spend a p2wpkh output.
    let script_code = dummy_utxo
        .script_pubkey
        .p2wpkh_script_code()
        .expect("valid script");

    // The input for the transaction we are constructing.
    let input = TxIn {
        previous_output: dummy_out_point,
        script_sig: ScriptBuf::new(),
        sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
        witness: Witness::default(),
    };

    // The spend output is locked to a key controlled by the receiver.
    let spend = TxOut {
        value: SPEND_AMOUNT,
        script_pubkey: address.script_pubkey(),
    };

    // The change output is locked to a key controlled by us.
    let change = TxOut {
        value: CHANGE_AMOUNT,
        script_pubkey: ScriptBuf::new_v0_p2wpkh(&wpkh),
    };

    // The transaction we want to sign and broadcast.
    let unsigned_tx = Transaction {
        version: 2,
        lock_time: absolute::LockTime::ZERO,
        input: vec![input],
        output: vec![spend, change],
    };

    // Sign the unsigned transaction.
    let mut sighash_cache = SighashCache::new(unsigned_tx);
    let sighash = sighash_cache
        .segwit_signature_hash(0, &script_code, DUMMY_UTXO_AMOUNT, EcdsaSighashType::All)
        .expect("valid sighash");
    let msg = Message::from(sighash);
    let sig = secp.sign_ecdsa(&msg, &sk);

    // Convert into a transaction
    let mut tx = sighash_cache.into_transaction();

    // Update the witness stack
    let pk = sk.public_key(&secp);
    let mut witness = &mut tx.input[0].witness;
    witness.push_bitcoin_signature(
        &sig.serialize_der(),
        EcdsaSighashType::All
    );
    witness.push(&pk.serialize());

    // Print the transaction ready to broadcast
    println!("tx: {tx:?}");
}
```

Let's go over the main function code block by block.

`let secp = Secp256k1::new();` creates a new `Secp256k1` context with all capabilities.
Since we added the `rand-std` feature to our `Cargo.toml`,
we can use the [`SecretKey::new`](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.Secp256k1.html#method.new) method to generate a random private key `sk`.

`let (sk, wpkh) = senders_keys(&secp);` generates a random private key `sk` and derives the corresponding public key hash `wpkh`.
`let address = receivers_address();` generates a receiver's address `address`.
`let (dummy_out_point, dummy_utxo) = dummy_unspent_transaction_output(&wpkh);` generates a dummy unspent transaction output `dummy_utxo` and its corresponding outpoint `dummy_out_point`.
All of these are helper functions that we defined earlier.

`let script_code = dummy_utxo.script_pubkey.p2wpkh_script_code().expect("valid script");`
creates the script code required to spend a P2WPKH output.
Since `dummy_utxo` is a [`TxOut`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.TxOut.html) type,
we can access the underlying public field `script_pubkey` which, in turn is a [`Script`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.Script.html) type.
We then use the [`p2wpkh_script_code`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.p2wpkh_script_code) method to generate the script code.

In `let input = TxIn {...}` we are instantiating the input for the transaction we are constructing
Inside the [`TxIn`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.TxIn.html) struct we are setting the following fields:

- `previous_output` is the outpoint of the dummy UTXO we are spending; it is a [`OutPoint`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.OutPoint.html) type.
- `script_sig` is the script code required to spend a P2WPKH output; it is a [`ScriptBuf`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   It should be empty. That's why the `ScriptBuf::new()`.
- `sequence` is the sequence number; it is a [`Sequence`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.Sequence.html) type.
   We are using the [`ENABLE_RBF_NO_LOCKTIME`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.Sequence.html#associatedconstant.ENABLE_RBF_NO_LOCKTIME) constant.
- `witness` is the witness stack; it is a [`Witness`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/witness/struct.Witness.html) type.
   We are using the [`default`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/witness/struct.Witness.html#impl-Default) method to create an empty witness that will be filled in later after signing.
   This is possible because `Witness` implements the [`Default`](https://doc.rust-lang.org/std/default/trait.Default.html) trait.

In `let spend = TxOut {...}` we are instantiating the spend output.
Inside the [`TxOut`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.TxOut.html) struct we are setting the following fields:

- `value` is the amount we are spending; it is a [`u64`](https://doc.rust-lang.org/std/primitive.u64.html) type.
   We are using the `const SPEND_AMOUNT` that we defined earlier.
- `script_pubkey` is the script code required to spend a P2WPKH output; it is a [`ScriptBuf`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   We are using the [`script_pubkey`](https://docs.rs/bitcoin/0.30.0/bitcoin/address/struct.Address.html#method.script_pubkey) method to generate the script pubkey from the receivers address.
   This will lock the output to the receiver's address.

In `let change = TxOut {...}` we are instantiating the change output.
It is very similar to the `spend` output, but we are now using the `const CHANGE_AMOUNT` that we defined earlier[^spend].
This is done by setting the `script_pubkey` field to [`ScriptBuf::new_v0_p2wpkh(&wpkh)`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new_v0_p2wpkh),
which generates P2WPKH-type of script pubkey.

In `let unsigned_tx = Transaction {...}` we are instantiating the transaction we want to sign and broadcast using the [`Transaction`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.Transaction.html) struct.
We set the following fields:

- `version` is the transaction version; it is a [`i32`](https://doc.rust-lang.org/std/primitive.u32.html) type.
   We are using version `2` which means that [BIP68](https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki) applies.
- `lock_time` is the transaction lock time;
   it is a [`LockTime`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html) enum.
   We are using the constant [`ZERO`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html#associatedconstant.ZERO)
   This will make the transaction valid immediately.
- `input` is the input vector; it is a [`Vec<TxIn>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `input` variable that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.
- `output` is the output vector; it is a [`Vec<TxOut>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `spend` and `change` variables that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.

In `let mut sighash_cache = SighashCache::new(unsigned_tx);` we are instantiating a [`SighashCache`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/struct.SighashCache.html) struct.
This is a type that efficiently calculates [signature hash message](https://developer.bitcoin.org/devguide/transactions.html?highlight=sighash_all#signature-hash-types) for legacy, segwit and taproot inputs.
We are using the `new` method to instantiate the struct with the `unsigned_tx` that we defined earlier.
`new` takes any `Borrow<Transaction>` as an argument.
[`Borrow<T>`](https://doc.rust-lang.org/std/borrow/trait.Borrow.html) is a trait that allows us to pass either a reference to a `T` or a `T` itself.
Hence, you can pass a `Transaction` or a `&Transaction` to `new`.

`sighash_cache` is instantiated as mutable because we require a mutable reference when creating the sighash to sign using [`segwit_signature_hash`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/struct.SighashCache.html#method.segwit_signature_hash).
This computes the [BIP143](https://github.com/bitcoin/bips/blob/master/bip-0143.mediawiki) sighash for any flag type.
It takes the following arguments:

- `input_index` is the index of the input we are signing; it is a [`usize`](https://doc.rust-lang.org/std/primitive.usize.html) type.
   We are using `0` since we only have one input.
- `script_code` is the script code required to spend a P2WPKH output; it is a reference to [`Script`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/script/struct.Script.html) type.
   We are using the `script_code` variable that we defined earlier.
- `value` is the amount of the UTXO we are spending; it is a [`u64`](https://doc.rust-lang.org/std/primitive.u64.html) type.
   We are using the `const DUMMY_UTXO_AMOUNT` that we defined earlier.
- `sighash_type` is the type of sighash; it is a [`EcdsaSighashType`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/enum.EcdsaSighashType.html) enum.
   We are using the [`All`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/enum.EcdsaSighashType.html#variant.All) variant,
   which indicates that the sighash will include all the inputs and outputs.

We create the message `msg` by converting the `sighash` to a [`Message`](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.Message.html) type.
This is the message that we will sign.
The [Message::from](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.Message.html#impl-From%3C%26%27_%20bitcoin%3A%3Ahashes%3A%3Asha256d%3A%3AHash%3E) method takes anything that implements the promises to be a thirty two byte hash i.e., 32 bytes that came from a cryptographically secure hashing algorithm.

We compute the signature `sig` by using the [`sign_ecdsa`](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.Secp256k1.html#method.sign_ecdsa) method.
It takes a refence to a [`Message`](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.Message.html) and a reference to a [`SecretKey`](https://docs.rs/secp256k1/0.27.0/secp256k1/struct.SecretKey.html) as arguments,
and returns a [`Signature`](https://docs.rs/secp256k1/0.27.0/secp256k1/ecdsa/struct.Signature.html) type.

In the next step, we update the witness stack for the input we just signed by first converting the `sighash_cache` into a [`Transaction`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/transaction/struct.Transaction.html)
by using the [`into_transaction`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/struct.SighashCache.html#method.into_transaction) method.
We access the witness field of the first input with `tx.input[0].witness`.
It is a [`Witness`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/witness/struct.Witness.html) type.
We use the [`push_bitcoin_signature`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/witness/struct.Witness.html#method.push_bitcoin_signature) method.
It expects two arguments:

1. A reference to a [`SerializedSignature`](https://docs.rs/secp256k1/0.27.0/secp256k1/ecdsa/serialized_signature/struct.SerializedSignature.html) type.
   This is accomplished by calling the [`serialize_der`](https://docs.rs/secp256k1/0.27.0/secp256k1/ecdsa/struct.Signature.html#method.serialize_der) method on the `Signature` `sig`,
   which returns a `SerializedSignature` type.
1. A [`EcdsaSighashType`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/enum.EcdsaSighashType.html) enum.
   Again we are using the same [`All`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/enum.EcdsaSighashType.html#variant.All) variant that we used earlier.

We repeat the same step as above, but now using the [`push`](https://docs.rs/bitcoin/0.30.0/bitcoin/blockdata/witness/struct.Witness.html#method.push) method
to push the serialized public key to the witness stack.
It expects a single argument of type `AsRef<[u8]>` which is a reference to a byte slice.

As the last step we print this to terminal using the [`println!`](https://doc.rust-lang.org/std/macro.println.html) macro.
This transaction is now ready to be broadcast to the Bitcoin network.

<!-- markdown-link-check-disable -->
[^today]: mid-2023.
<!-- markdown-link-check-enable -->

[^change]: Please note that the `CHANGE_AMOUNT` is not the same as the `DUMMY_UTXO_AMOUNT` minus the `SPEND_AMOUNT`.
           This is due to the fact that we need to pay a fee for the transaction.

[^expect]: We will be unwraping any [`Option<T>`](https://doc.rust-lang.org/std/option)/[`Result<T, E>`](https://doc.rust-lang.org/std/result)
           with the `expect` method.

[^secp]: Under the hood we are using the [`secp256k1`](https://github.com/rust-bitcoin/rust-secp256k1/) crate to generate the key pair.
         `rust-secp256k1` is a wrapper around [libsecp256k1](https://github.com/bitcoin-core/secp256k1), a C
         library implementing various cryptographic functions using the [SECG](https://www.secg.org/) curve
         [secp256k1](https://en.bitcoin.it/wiki/Secp256k1).

[^spend]: And also we are locking the output to an address that we control:
          the `wpkh` public key hash that we generated earlier. 