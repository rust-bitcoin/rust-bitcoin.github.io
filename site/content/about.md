---
title: "About"
date: 2023-02-15T11:15:39+11:00
draft: false
---

**rust-bitcoin** refers to the GitHub rust-bitcoin organization and also to the main repository (and
Rust crate) within that organization.

The rust-bitcoin crate is a library that supports the Bitcoin network protocol and associated
primitives. It is designed for Rust programs built to work with the Bitcoin network.

### Crates

The rust-bitcoin organization includes a number of repositories containing various Rust crates that
you may find useful when writing Rust code that interacts with the Bitcoin network.

- [rust-bitcoincore-rpc](https://github.com/rust-bitcoin/rust-bitcoincore-rpc): A client library for
  the Bitcoin Core JSON-RPC API.

- [rust-miniscript](https://github.com/rust-bitcoin/rust-miniscript): Miniscript is an alternative
  to Bitcoin Script. It can be efficiently and simply encoded as Script to ensure that it works on
  the Bitcoin blockchain, but its design is very different.

- [rust-bitcoin](https://github.com/rust-bitcoin/rust-bitcoin): Your one-stop-shop for interacting
  with the Bitcoin network in Rust.

- [bitcoin-hashes](https://github.com/rust-bitcoin/rust-bitcoin/tree/master/hashes): A simple,
  no-dependency library which implements the hash functions needed by Bitcoin.

- [rust-secp256k1](https://github.com/rust-bitcoin/rust-secp256k1): Rust bindings for Pieter
  Wuille's secp256k1 library, which is used for fast and accurate manipulation of signatures on the
  secp256k1 curve.

- [rust-bitcoinconsensus](https://github.com/rust-bitcoin/rust-bitcoinconsensus): Rust bindings for
  the libbitcoinconsensus library from Bitcoin Core.
  
- [rust-bech32](https://github.com/rust-bitcoin/rust-bech32): Rust implementation of the Bech32
  encoding format described in BIP-0173 and Bech32m encoding format described in BIP-0350.
  
### Projects
  
Currently rust-bitcoin is used by a number of projects, including:
- [electrs](https://github.com/romanz/electrs): Electrum server in Rust.
- [Bitcoin Dev Kit (BDK)](https://github.com/bitcoindevkit): A library that allows you to seamlessly build
  cross-platform Bitcoin wallets without worrying about bitcoin internals.
- [Lightning Dev Kit (LDK)](https://github.com/lightningdevkit): A library that allows you to build a
  lightning node without worrying about implementing low-level lightning logic correctly.
