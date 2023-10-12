---
title: "Release 0.30.0 is out!"
date: 2023-03-21T12:00:00-07:00
draft: false
---

`rust-bitcoin` [version 0.30.0](https://docs.rs/bitcoin/0.30.0/bitcoin/index.html) is out now.

<!--more-->

This is a rather large release so we decided to write an update guide for you guys. If this guide is
not useful or lacking in some way please do let us know so we can do better.

First a little excuse for why this is going to be so painful. We try to deprecate things when we
make API breaking changes, using

     #[deprecated(since = "x.y.z", note = "use foobar instead")]

This allows us to give you a hint on how to upgrade by way of the compiler. The problem we hit was
that its not always possible to deprecate things (e.g. changing arguments to a function) so under
the cover of "this is a pre-1.0 release" and with the aim of pushing kind of fast so we can get to
the 1.0 release, we got a bit sloppy with deprecation this release - sorry about that. We are very
much trying to get to a place where we can commit to our APIs and stabilize the codebase, that is
the primary goal of development at the moment. If you have API changing suggestions or requests
please get them into us now so your needs can be met.

Without further ado, here is the upgrade guide. Enjoy!

## Suggested steps

We suggest that you take these steps when upgrading:

0. Make sure to update other dependency versions in `Cargo.toml` if you use them explicitly: `bitcoin_hashes` to 0.12.0, `secp256k1` to 0.27.0
1. Remove all occurrences of `util::` referring to our crate
2. Replace `Script` with [`ScriptBuf`](https://docs.rs/bitcoin/0.30.0/bitcoin/script/struct.ScriptBuf.html) (`s/\([^A-Za-z0-9]\)Script\([^A-Za-z0-9]\)/\1ScriptBuf\2/g` should work in most cases)
3. Replace instances of `.parse::<Address>()` with `.parse::<Address<_>>()`
4. Call `require_network(network)` on parsed addresses (you'll get no method found for `Address<NetworkUnchecked>` errors)
5. Replace `locktime` with [`locktime::absolute`](https://docs.rs/bitcoin/0.30.0/bitcoin/locktime/absolute/index.html)
6. Replace `PackedLockTime` with just [`LockTime`](https://docs.rs/bitcoin/0.30.0/bitcoin/locktime/absolute/struct.LockTime.html)
7. Import key types from the `key` submodule rather than `schnorr` or `ecdsa`
8. Replace `SchnorrSighashType` with [`TapSighashType`](https://docs.rs/bitcoin/0.30.0/bitcoin/sighash/struct.TapSighashType.html)
9. Replace `TapBranchHash` with [`TapNodeHash`](https://docs.rs/bitcoin/0.30.0/bitcoin/taproot/struct.TapNodeHash.html)
10. Change `hash_newtype!(FooHash, sha256::Hash, 32, doc="A hash of foo.");` to:

```rust
hash_newtype! {
    /// A hash of foo.
    pub struct FooHash(sha256::Hash);
}
```

11. Fix outstanding compiler errors, if any
12. Optimize the code: replace occurrences of `&ScriptBuf` with `Script`, remove allocations...
13. Remove useless conversions `LockTime` -> `LockTime` (clippy has a lint for it)

These steps should get you most of the way - see "Renames" section below also.

## Re-exports

We are trying to separate the API from the directory structure, as part of this we are attempting to
only re-export from the crate root types that exist in the standard Bitcoin vernacular i.e., for
pubkey you can `use bitcoin::PublicKey` but to get an x-only pubkey you need to go to the `key`
module `use bitcoin::key::XOnlyPublicKey`.

Please note this is still work-in-progress, suggestions welcome.

## Code moves

We moved _a lot_ of stuff around. This was a precursor to crate smashing which we have now started.
Hopefully things are in intuitive places, it might be useful to take a quick look at the new
module structure to get a feel for things, specifically:

- We have a workspace now! The main crate now lives in `bitcoin/`. The `bitcoin_hashes` repository
  has been merged into the `rust-bitcoin` repository and now lives under `hashes/`.

- The `util` module is all but gone, try just removing `util::` at first, most modules are
  re-exported at the crate root.

- Cryptography related stuff can now primarily be found in 4 modules (`ecdsa`, `taproot`, `sighash`,
  `key`). We have started to break ECDSA stuff up into legacy and segwit v0 where it is cleaner but
  this is still work-in-progress.

- Some hash wrapper types are now to be found in the module that they are used in e.g.,
  `TapLeafHash` is in the `taproot` module. Others are still in `hash_types` but the re-exports now
  conform to the aim stated above so you might need to add `hash_types::` to your paths for the more
  esoteric hash types.

## Script changes

To optimize efficiency of working with borrowed scripts we renamed `Script` to `ScriptBuf` and added
an unsized `Script`. It works just like `PathBuf` and `Path` (and other such types) from `std`. The
API tries to resemble those types as much as reasonable (deref coercions etc.), so it should be
intuitive. Methods in the library that previously took `&Script` (which is now `ScriptBuf`) take the
unsized `&Script` now.

Additionally, we changed the type accepted by the `push_slice` method to be another unsized newtype:
`PushBytes` and it's owned counterpart `PushBytesBuf`. These types maintain the invariant of storing
at most 2^32-1 bytes - the maximum one can push into script. Previously the method would panic if
you attempted to do it (and it wasn't documented, sorry about that). Now you can either handle it
explicitly using `TryFrom` or just pass a known-length array (implemented for arrays up to 73
bytes).

Types that are commonly pushed into script (serialized signatures, public keys...) implement
`AsRef<PushBytes>` so you can pass those directly as well. You can also implement `AsRef` for your
types so they can be pushed directly.

## Taproot changes

Since the introduction of Taproot support the API got "stress tested" and various issues were
uncovered and fixed. One of them is that the name "Branch Hash" refers to the algorithm being used
to compute the value but the resulting value is actually a node in the tree. Thus we renamed
`TapBranchHash` to `TapNodeHash` to reflect this. Additionally we originally used raw
`sha256::Hashes` for node hashes which was error-prone and annoying because of manual conversions.
We changed them to use `TapNodeHash` instead.

When writing smart contracts that have their taproot trees statically known it was annoying to use
`TaprootMerkleBranch::try_from` for arrays that are statically known to be shorter than 128. We've
added `From` conversion for these.

`NodeInfo` got some improvements too. For trees that are statically guaranteed to not have hidden
nodes we have `TapTree` type and both got methods for getting an iterator over their respective
items. This also improved our code internally, fixing some bugs and decreasing the risk of other
bugs. We have some additional ideas to improve it further.

Some types that do not have a well-defined serialization in the Bitcoin ecosystem or are purely Rust
constructs (e.g. builders) got serde support removed. Serializing these would be error-prone and
difficult to support stably. You can instead (de)serialize other types and convert them.

Overall, these changes should make working with Taproot less error-prone and more ergonomic. Taproot
is still young technology so it's possible there will be more changes in the future as new users try
out the API. Please let us know if you have questions or suggestions.

## Sighash

We moved around and renamed a bunch of types to do with sighashes. In the `sighash` module, along
with the `SighashCache` we now have the hopefully clearly named:

- `LegacySighash`
- `SegwitV0Sighash`
- `TapSighash`
- `EcdsaSighashType`
- `TapSighashType`

Signatures are now in their respective modules (`ecdsa` for legacy and segwit v0):

- `taproot::Signature`
- `ecdsa::Signature`

## Lock types

There are now two lock times, one for absolute locks (CLTV) and one for relative locks (CSV). We
export the `absolute` and `relative` modules at the crate root so you can either import them from
there or `use bitcoin::locktime::{absolute, relative};` if that's clearer. We expect locks to be
used as `absolute::LockTime`.

## Address changes

Bitcoin addresses for different networks are different, up until this release, when parsing an
address from a string, a check that the address format matched up to the expected network (e.g. "bc1"
prefix for Bitcoin mainnet segwit addresses) was available but easy to forget. We've attempted to
improve the API to make such omissions harder.

Now `Address<V>` includes a generic that is used as a marker for whether the address has been
checked as valid for a particular network, we have `Address<NetworkChecked>` and
`Address<NetworkUnchecked>`, defaulting to `NetworkChecked`. Because of the default some uses will
just keep working but you should be aware that `Address` now means `Address<NetworkChecked>`. The
string parsing functions return types as expected. See the docs on `Address` for more information.

## Newtypes

This is a non-exhaustive list of newtypes added this release:

- `relative::LockTime`
- `relative::Height`
- `relative::Time`
- `ecdsa::SerializedSignature`
- `ScriptBuf`
- `PushBytes` / `PushBytesBuf`
- `Target`
- `CompactTarget`
- `Work`

### Renames

This is a non-exhaustive list of types renamed in this release:

- `Script` -> `ScriptBuf`
- `locktime::LockTime` -> `locktime::absolute::LockTime`
- `locktime::Time` -> `locktime::absolute::Time`
- `locktime::Height` -> `locktime::absolute::Height`
- `TapBranchHash` / `TapLeafHash` -> `TapNodeHash`
- `TapSighashHash` -> `TapSighash`
- `SchnorrSighashtype` -> `TapSighashType`
- `schnorr` -> `taproot` (module rename)
- Various error types were renamed, we try to use `foo::Error` if there is a single error type in
  the `foo` module.

### Removed types

- `PackedLockTime`

This type was intended as an optimization of the absolute locktime using a `u32`, this turned out to
be not such a great idea. Please note `absolute::LockTime` does not implement `Ord`.

- `Uint256`

We changed the `Uint256` type to `U256` and made it private since it is not a general purpose
integer type. Rather we wrapped it to create the `Work` and `Target` types.

## Final thoughts

I've tried to give you some context on why so many changes. Hopefully the context makes the upgrade
path easier and helps to clarify the direction we are pushing in at the moment. As always,
contributions are most welcome, issues, PRs, and even just ideas. We are here to provide the best
crate we can for devs wishing to interact with the Bitcoin network in Rust, feedback from your
usecase helps us a lot, help us out so we can help you.

Thanks,  
Tobin (and the rust-bitcoin devs).
