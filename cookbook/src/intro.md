# Introduction

This book is created and maintained by those involved in the
[`rust-bitcoin`](https://github.com/rust-bitcoin) GitHub organization, contributions are
appreciated. It covers various crates from the org and as such, aims to be useful to developers
wanting to write code in Rust that interacts with the Bitcoin network. It is specifically not
limited to just the [`rust-bitcoin`](https://github.com/rust-bitcoin/rust-bitcoin) crate, although
that is a good starting point if you want a one-stop-shop for interacting with Bitcoin in Rust.

There are a number of good libraries outside of the `rust-bitcoin` organization that use the crates
covered here, two that you might like to check out are:

- [`Bitcoin Dev Kit`](https://bitcoindevkit.org/)
- [`Lightning Dev Kit`](https://lightningdevkit.org/)

Finally, this book is currently a work in progress but hopes to eventually cover various topics,
including parsing blocks and transactions, constructing and signing transactions, receiving data
over the peer-to-peer network, plus fun stuff you can do with miniscript.

## Table of Contents

1. [Getting Started](getting_started.md)
1. [Constructing and Signing Transactions](tx.md)
    1. [SegWit V0](tx_segwit-v0.md)
    1. [Taproot](tx_taproot.md)

## License

This website is licensed under [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication][cc].

[![CC BY-SA 4.0][cc-image]][cc]

[cc]: https://creativecommons.org/publicdomain/zero/1.0/
[cc-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-shield]: https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg
