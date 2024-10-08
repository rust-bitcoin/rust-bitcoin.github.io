# Constructing and Signing Transactions - Taproot

In this section, we will construct a [Taproot transaction](https://bitcoinops.org/en/topics/taproot/).

This is the `cargo` commands that you need to run this example:

```bash
cargo add bitcoin --features "std, rand-std"
```

First we'll need to import the following:

```rust
use bitcoin::hashes::Hash;
use bitcoin::key::{Keypair, TapTweak, TweakedKeypair, UntweakedPublicKey};
use bitcoin::locktime::absolute;
use bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing, Verification};
use bitcoin::sighash::{Prevouts, SighashCache, TapSighashType};
use bitcoin::{
    transaction, Address, Amount, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut,
    Txid, Witness,
};
```

Here is the logic behind these imports:

- `bitcoin::key` is used to tweak keys according to [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- `bitcoin::hashes::Hash` is used to hash data
- `bitcoin::locktime::absolute` is used to create a locktime
- `bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing, Verification}` is used to sign transactions
- `use bitcoin::sighash::{Prevouts, SighashCache, TapSighashType}` is used to create and tweak taproot sighashes
- `bitcoin::{Address, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid, Witness}` is used to construct transactions

Next, we define the following constants:

```rust
# use bitcoin::Amount;
const DUMMY_UTXO_AMOUNT: Amount = Amount::from_sat(20_000_000);
const SPEND_AMOUNT: Amount = Amount::from_sat(5_000_000);
const CHANGE_AMOUNT: Amount = Amount::from_sat(14_999_000); // 1000 sat fee.
```

- `DUMMY_UTXO_AMOUNT` is the amount of the dummy UTXO we will be spending
- `SPEND_AMOUNT` is the amount we will be spending from the dummy UTXO
- `CHANGE_AMOUNT`[^change] is the amount we will be sending back to ourselves as change

Before we can construct the transaction, we need to define some helper functions[^expect]:

```rust
# use bitcoin::secp256k1::{rand, Secp256k1, SecretKey, Signing};
# use bitcoin::key::Keypair;
fn senders_keys<C: Signing>(secp: &Secp256k1<C>) -> Keypair {
    let sk = SecretKey::new(&mut rand::thread_rng());
    Keypair::from_secret_key(secp, &sk)
}
```

`senders_keys` generates a random private key and derives the corresponding public key hash.
This will be useful to mock a sender.
In a real application these would be actual secrets[^secp].
We use the `SecretKey::new` method to generate a random private key `sk`.
We then use the [`Keypair::from_secret_key`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/struct.Keypair.html#method.from_secret_key) method to instantiate a [`Keypair`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/struct.Keypair.html) type,
which is a data structure that holds a keypair consisting of a secret and a public key.
Note that `senders_keys` is generic over the [`Signing`](https://docs.rs/secp256k1/0.29.0/secp256k1/trait.Signing.html) trait.
This is used to indicate that is an instance of `Secp256k1` and can be used for signing.

```rust
# use bitcoin::{Address, Network};
fn receivers_address() -> Address {
    "bc1p0dq0tzg2r780hldthn5mrznmpxsxc0jux5f20fwj0z3wqxxk6fpqm7q0va".parse::<Address<_>>()
        .expect("a valid address")
        .require_network(Network::Bitcoin)
        .expect("valid address for mainnet")
}
```

`receivers_address` generates a receiver address.
In a real application this would be the address of the receiver.
We use the `parse` method on `&str` to parse `"bc1p0dq0tzg2r780hldthn5mrznmpxsxc0jux5f20fwj0z3wqxxk6fpqm7q0va"`[^arbitrary_address] as an address.
Note that `bc1p0dq0tzg2r780hldthn5mrznmpxsxc0jux5f20fwj0z3wqxxk6fpqm7q0va` is a [Bech32](https://bitcoinops.org/en/topics/bech32/) address.
This is an arbitrary, however valid, Bitcoin mainnet address.
Bitcoin applications are usually configured with specific Bitcoin network at the start and use that.
To prevent mistakes related to people sending satoshis to a wrong network we need to call the `require_network` method to ensure that the address is valid for the network, in our case mainnet.

```rust
# use bitcoin::{Amount, OutPoint, ScriptBuf, TxOut, Txid};
# use bitcoin::hashes::Hash;
# use bitcoin::key::UntweakedPublicKey;
# use bitcoin::locktime::absolute;
# use bitcoin::secp256k1::{Secp256k1, Verification};
# const DUMMY_UTXO_AMOUNT: Amount = Amount::from_sat(20_000_000);
fn dummy_unspent_transaction_output<C: Verification>(
   secp: &Secp256k1<C>,
   internal_key: UntweakedPublicKey,
) -> (OutPoint, TxOut) {
    let script_pubkey = ScriptBuf::new_p2tr(secp, internal_key, None);

    let out_point = OutPoint {
        txid: Txid::all_zeros(), // Obviously invalid.
        vout: 0,
    };

    let utxo = TxOut { value: DUMMY_UTXO_AMOUNT, script_pubkey };

    (out_point, utxo)
}
```

`dummy_unspent_transaction_output` generates a dummy unspent transaction output (UTXO).
This is a P2TR (`ScriptBuf::new_p2tr`) UTXO.
It takes the following arguments:

- `secp` is a reference to a [`Secp256k1`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Secp256k1.html) type.
   This is used to verify the internal key.
- `internal_key` is a [`UntweakedPublicKey`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/type.UntweakedPublicKey.html) type.
   This is the internal key that is used to generate the script pubkey.
   It is untweaked, since we are not going to tweak the key.
- `merkle_root` is an optional [`TapNodeHash`](https://docs.rs/bitcoin/0.32.0/bitcoin/taproot/struct.TapNodeHash.html) type.
   This is the merkle root of the taproot tree.
   Since we are not using a merkle tree, we are passing `None`.

[`Verification`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/trait.Verification.html) is a trait that indicates that an instance of `Secp256k1` can be used for verification.
The UTXO has a dummy invalid transaction ID (`txid: Txid::all_zeros()`),
and a value of the `const DUMMY_UTXO_AMOUNT` that we defined earlier.
P2TR UTXOs could be tweaked ([`TweakedPublicKey`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/struct.TweakedPublicKey.html))
or untweaked ([`UntweakedPublicKey`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/type.UntweakedPublicKey.html)).
We are using the latter, since we are not going to tweak the key.
We are using the [`OutPoint`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.OutPoint.html) struct to represent the previous transaction output.
Finally, we return the tuple `(out_point, utxo)`.

Now we are ready for our main function that will sign a transaction that spends a `p2tr` unspent output:

```rust
# use bitcoin::hashes::Hash;
# use bitcoin::key::{Keypair, TapTweak, TweakedKeypair, UntweakedPublicKey};
# use bitcoin::locktime::absolute;
# use bitcoin::secp256k1::{rand, Message, Secp256k1, SecretKey, Signing, Verification};
# use bitcoin::sighash::{Prevouts, SighashCache, TapSighashType};
# use bitcoin::{
#     transaction, Address, Amount, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut,
#     Txid, Witness,
# };
#
# const DUMMY_UTXO_AMOUNT: Amount = Amount::from_sat(20_000_000);
# const SPEND_AMOUNT: Amount = Amount::from_sat(5_000_000);
# const CHANGE_AMOUNT: Amount = Amount::from_sat(14_999_000); // 1000 sat fee.
#
# fn senders_keys<C: Signing>(secp: &Secp256k1<C>) -> Keypair {
#     let sk = SecretKey::new(&mut rand::thread_rng());
#     Keypair::from_secret_key(secp, &sk)
# }
# 
# fn receivers_address() -> Address {
#     "bc1p0dq0tzg2r780hldthn5mrznmpxsxc0jux5f20fwj0z3wqxxk6fpqm7q0va".parse::<Address<_>>()
#         .expect("a valid address")
#         .require_network(Network::Bitcoin)
#         .expect("valid address for mainnet")
# }
# 
# fn dummy_unspent_transaction_output<C: Verification>(
#    secp: &Secp256k1<C>,
#    internal_key: UntweakedPublicKey,
# ) -> (OutPoint, TxOut) {
#     let script_pubkey = ScriptBuf::new_p2tr(secp, internal_key, None);
# 
#     let out_point = OutPoint {
#         txid: Txid::all_zeros(), // Obviously invalid.
#         vout: 0,
#     };
# 
#     let utxo = TxOut { value: DUMMY_UTXO_AMOUNT, script_pubkey };
# 
#     (out_point, utxo)
# }

fn main() {
    let secp = Secp256k1::new();

    // Get a keypair we control. In a real application these would come from a stored secret.
    let keypair = senders_keys(&secp);
    let (internal_key, _parity) = keypair.x_only_public_key();

    // Get an unspent output that is locked to the key above that we control.
    // In a real application these would come from the chain.
    let (dummy_out_point, dummy_utxo) = dummy_unspent_transaction_output(&secp, internal_key);

    // Get an address to send to.
    let address = receivers_address();

    // The input for the transaction we are constructing.
    let input = TxIn {
        previous_output: dummy_out_point, // The dummy output we are spending.
        script_sig: ScriptBuf::default(), // For a p2tr script_sig is empty.
        sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
        witness: Witness::default(), // Filled in after signing.
    };

    // The spend output is locked to a key controlled by the receiver.
    let spend = TxOut { value: SPEND_AMOUNT, script_pubkey: address.script_pubkey() };

    // The change output is locked to a key controlled by us.
    let change = TxOut {
        value: CHANGE_AMOUNT,
        script_pubkey: ScriptBuf::new_p2tr(&secp, internal_key, None), // Change comes back to us.
    };

    // The transaction we want to sign and broadcast.
    let mut unsigned_tx = Transaction {
        version: transaction::Version::TWO,  // Post BIP-68.
        lock_time: absolute::LockTime::ZERO, // Ignore the locktime.
        input: vec![input],                  // Input goes into index 0.
        output: vec![spend, change],         // Outputs, order does not matter.
    };
    let input_index = 0;

    // Get the sighash to sign.

    let sighash_type = TapSighashType::Default;
    let prevouts = vec![dummy_utxo];
    let prevouts = Prevouts::All(&prevouts);

    let mut sighasher = SighashCache::new(&mut unsigned_tx);
    let sighash = sighasher
        .taproot_key_spend_signature_hash(input_index, &prevouts, sighash_type)
        .expect("failed to construct sighash");

    // Sign the sighash using the secp256k1 library (exported by rust-bitcoin).
    let tweaked: TweakedKeypair = keypair.tap_tweak(&secp, None);
    let msg = Message::from_digest(sighash.to_byte_array());
    let signature = secp.sign_schnorr(&msg, &tweaked.to_inner());

    // Update the witness stack.
    let signature = bitcoin::taproot::Signature { signature, sighash_type };
    sighasher.witness_mut(input_index).unwrap().push(&signature.to_vec());

    // Get the signed transaction.
    let tx = sighasher.into_transaction();

    // BOOM! Transaction signed and ready to broadcast.
    println!("{:#?}", tx);
}
```

Let's go over the main function code block by block.

`let secp = Secp256k1::new();` creates a new `Secp256k1` context with all capabilities.
Since we added the `rand-std` feature to our `Cargo.toml`,
we can use the [`SecretKey::new`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Secp256k1.html#method.new) method to generate a random private key `sk`.

`let keypair = senders_keys(&secp);` generates a keypair that we control,
and `let (internal_key, _parity) = keypair.x_only_public_key();` generates a [`XOnlyPublicKey`](https://docs.rs/bitcoin/0.32.0/bitcoin/key/struct.XOnlyPublicKey.html) that represent an X-only public key, used for verification of Schnorr signatures according to [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki).
We won't be using second element from the returned tuple, the parity, so we are ignoring it by using the `_` underscore.
`let address = receivers_address();` generates a receiver's address `address`.
`let (dummy_out_point, dummy_utxo) = dummy_unspent_transaction_output(&secp, internal_key);` generates a dummy unspent transaction output `dummy_utxo` and its corresponding outpoint `dummy_out_point`.
All of these are helper functions that we defined earlier.

In `let input = TxIn {...}` we are instantiating the input for the transaction we are constructing
Inside the [`TxIn`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxIn.html) struct we are setting the following fields:

- `previous_output` is the outpoint of the dummy UTXO we are spending; it has the [`OutPoint`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.OutPoint.html) type.
- `script_sig` is the script code required to spend an output; it has the [`ScriptBuf`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   We are instantiating a new empty script with [`ScriptBuf::new()`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new).
- `sequence` is the sequence number; it has the [`Sequence`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Sequence.html) type.
   We are using the [`ENABLE_RBF_NO_LOCKTIME`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Sequence.html#associatedconstant.ENABLE_RBF_NO_LOCKTIME) constant.
- `witness` is the witness stack; has the [`Witness`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html) type.
   We are using the [`default`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html#impl-Default) method to create an empty witness that will be filled in later after signing.
   This is possible because `Witness` implements the [`Default`](https://doc.rust-lang.org/std/default/trait.Default.html) trait.

In `let spend = TxOut {...}` we are instantiating the spend output.
Inside the [`TxOut`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxOut.html) struct we are setting the following fields:

- `value` is the amount we are assigning to be spendable by given `script_pubkey`; it has the [`Amount`](https://docs.rs/bitcoin/0.32.0/bitcoin/struct.Amount.html) type.
   We are using the `const SPEND_AMOUNT` that we defined earlier.
- `script_pubkey` is the script code required to spend a P2TR output; it is a [`ScriptBuf`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html) type.
   We are using the [`script_pubkey`](https://docs.rs/bitcoin/0.32.0/bitcoin/address/struct.Address.html#method.script_pubkey) method to generate the script pubkey from the receivers address.
   This will lock the output to the receiver's address.

In `let change = TxOut {...}` we are instantiating the change output.
It is very similar to the `spend` output, but we are now using the `const CHANGE_AMOUNT` that we defined earlier[^spend].
This is done by setting the `script_pubkey` field to [`ScriptBuf::new_p2tr(...)`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/script/struct.ScriptBuf.html#method.new_p2tr),
which generates P2TR-type of script pubkey.

In `let unsigned_tx = Transaction {...}` we are instantiating the transaction we want to sign and broadcast using the [`Transaction`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Transaction.html) struct.
We set the following fields:

- `version` is the transaction version; it has the [`transaction::Version`](https://docs.rs/bitcoin/0.32.2/bitcoin/blockdata/transaction/struct.Version.html) type.
   We are using version `2` which means that [BIP68](https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki) applies.
- `lock_time` is the transaction lock time;
   it is a [`LockTime`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html) enum.
   We are using the constant [`ZERO`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/locktime/absolute/enum.LockTime.html#associatedconstant.ZERO)
   This will make the transaction valid immediately.
- `input` is the input vector; it is a [`Vec<TxIn>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `input` variable that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.
- `output` is the output vector; it is a [`Vec<TxOut>`](https://doc.rust-lang.org/std/vec/struct.Vec.html) type.
   We are using the `spend` and `change` variables that we defined earlier wrapped in the [`vec!`](https://doc.rust-lang.org/std/macro.vec.html) macro for convenient initialization.

We need to reference the outputs of previous transactions in our transaction.
We accomplish this with the [`Prevouts`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/enum.Prevouts.html) enum.
In `let prevouts = vec![dummy_utxo];`,
we create a vector of [`TxOut`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxOut.html) types that we want to reference.
In our case, we only have one output, the `dummy_utxo` that we defined earlier.
With `let prevouts = Prevouts::All(&prevouts);` we create a [`Prevouts::All`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/enum.Prevouts.html#variant.All) variant that takes a reference to a vector of [`TxOut`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.TxOut.html) types.

In `let mut sighash_cache = SighashCache::new(unsigned_tx);` we are instantiating a [`SighashCache`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/struct.SighashCache.html) struct.
This is a type that efficiently calculates [signature hash message](https://developer.bitcoin.org/devguide/transactions.html?highlight=sighash_all#signature-hash-types) for legacy, segwit and taproot inputs.
We are using the `new` method to instantiate the struct with the `unsigned_tx` that we defined earlier.
`new` takes any `Borrow<Transaction>` as an argument.
[`Borrow<T>`](https://doc.rust-lang.org/std/borrow/trait.Borrow.html) is a trait that allows us to pass either a reference to a `T` or a `T` itself.
Hence, you can pass a `Transaction`, a `&Transaction` or a smart pointer to `new`.

`sighash_cache` is bound as mutable because we are updating it with computed values during signing.
This is reflected by [`taproot_signature_hash`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/struct.SighashCache.html#method.taproot_signature_hash) taking a mutable reference.
This computes the [BIP341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) sighash for any flag type.
It takes the following arguments:

- `input_index` is the index of the input we are signing; it has the [`usize`](https://doc.rust-lang.org/std/primitive.usize.html) type.
   We are using `0` since we only have one input.
- `&prevouts` is a reference to the [`Prevouts`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/enum.Prevouts.html) enum that we defined earlier.
   This is used to reference the outputs of previous transactions and also used to calculate our transaction value.
- `annex` is an optional argument that is used to pass the annex data.
   We are not using it, so we are passing `None`.
- `leaf_hash_code_separator` is an optional argument that is used to pass the leaf hash code separator.
   We are not using it, so we are passing `None`.
- `sighash_type` is the type of sighash; it is a [`TapSighashType`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/enum.TapSighashType.html) enum.
   We are using the [`All`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/enum.TapSighashType.html#variant.All) variant,
   which indicates that the sighash will include all the inputs and outputs.

Since Taproot outputs contain the tweaked key and `keypair` represents untweaked (internal) key we have to tweak the key before signing using
`let tweaked: TweakedKeypair = keypair.tap_tweak(&secp, None);`.

We create the message `msg` by converting the `sighash` to a [`Message`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Message.html) type.
This is a the message that we will sign.
The [Message::from](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Message.html#impl-From%3C%26%27_%20bitcoin%3A%3Ahashes%3A%3Asha256d%3A%3AHash%3E) method is available for types that are intended and safe for signing.

We compute the signature `sig` by using the [`sign_schnorr`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Secp256k1.html#method.sign_schnorr) method.
It takes a reference to a [`Message`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Message.html) and a reference to a [`Keypair`](https://docs.rs/secp256k1/0.29.0/secp256k1/struct.Keypair.html) as arguments,
and returns a [`Signature`](https://docs.rs/secp256k1/0.29.0/secp256k1/ecdsa/struct.Signature.html) type.

In the next step, we update the witness stack for the input we just signed by first releasing the [`Transaction`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/transaction/struct.Transaction.html)
from `sighash_cache` by using the [`into_transaction`](https://docs.rs/bitcoin/0.32.0/bitcoin/sighash/struct.SighashCache.html#method.into_transaction) method.
We access the witness field of the first input with `tx.input[0].witness`.
It is a [`Witness`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html) type.
We use the [`push`](https://docs.rs/bitcoin/0.32.0/bitcoin/blockdata/witness/struct.Witness.html#method.push) method
to push the serialized public and private Taproot keys.
It expects a single argument of type `AsRef<[u8]>` which is a reference to a byte slice.
We are using the [`as_ref`](https://doc.rust-lang.org/std/convert/trait.AsRef.html) method to convert the signature `sig` to a byte slice.

As the last step we print this to terminal using the [`println!`](https://doc.rust-lang.org/std/macro.println.html) macro.
This transaction is now ready to be broadcast to the Bitcoin network.

[^change]: Please note that the `CHANGE_AMOUNT` is not the same as the `DUMMY_UTXO_AMOUNT` minus the `SPEND_AMOUNT`.
           This is due to the fact that we need to pay a fee for the transaction.

[^expect]: We will be unwrapping any [`Option<T>`](https://doc.rust-lang.org/std/option)/[`Result<T, E>`](https://doc.rust-lang.org/std/result)
           with the `expect` method.

[^secp]: Under the hood we are using the [`secp256k1`](https://github.com/rust-bitcoin/rust-secp256k1/) crate to generate the key pair.
         `rust-secp256k1` is a wrapper around [libsecp256k1](https://github.com/bitcoin-core/secp256k1), a C
         library implementing various cryptographic functions using the [SECG](https://www.secg.org/) curve
         [secp256k1](https://en.bitcoin.it/wiki/Secp256k1).

[^arbitrary_address]: this is an arbitrary mainnet address from block 805222.

[^spend]: And also we are locking the output to an address that we control:
          the `internal_key` public key hash that we generated earlier.
