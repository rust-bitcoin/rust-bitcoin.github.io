# Rust Bitcoin

[`rust-bitcoin`](https://github.com/rust-bitcoin/rust-bitcoin) is a library for working with Bitcoin in Rust.
It contains Bitcoin network protocol and associated primitives.
You can find more by reading the [documentation](https://docs.rs/bitcoin).

To add `rust-bitcoin` to your project, run:

```bash
cargo add bitcoin
```

Additionally, you can add flags to enable features.
Here's an example:

```bash
cargo add bitcoin --features=rand-std
```

This cookbook provides straightforward examples that showcase effective approaches
for accomplishing typical Bitcoin-related programming tasks,
and utilizing the Rust ecosystem's crates.

The book covers various topics, including receiving data over P2P,
parsing blocks and transactions,
and constructing and signing transactions.

## Table of Contents

This book contains:

1. [Constructing and Signing Transactions](tx.md)
    1. [SegWit V0](tx_segwit-v0.md)
    1. [Taproot](tx_taproot.md)

## License

This website is licensed under [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication][cc].

[![CC BY-SA 4.0][cc-image]][cc]

[cc]: https://creativecommons.org/publicdomain/zero/1.0/
[cc-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-shield]: https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg
