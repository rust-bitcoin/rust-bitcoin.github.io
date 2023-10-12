# Rust Bitcoin Cookbook

[![CC0 1.0][cc-shield]][cc]

Welcome to the `rust-bitcoin` cookbook!
This cookbook is designed to provide readers with a
comprehensive understanding of `rust-bitcoin` and its key features.
Don't forget to check [`rust-bitcoin`'s documentation](https://docs.rs/bitcoin)

## How to contribute

For the cookbook we use [`mdbook`](https://rust-lang.github.io/mdBook).
Please check how to install it on your system.

To build the cookbook locally, run:

```bash
mdbook build
```

If you want to preview the cookbook locally, run:

```bash
mdbook serve
```

### Testing the code snippets

Since [`mdbook` does not support external crates](https://github.com/rust-lang/mdBook/issues/706),
we use [a solution provided by `doc-comment`](https://github.com/rust-lang/mdBook/issues/706#issuecomment-1139423009)
to test the code snippets in the cookbook.
First, go to the `tests/` directory:

```bash
cd tests
```

Then, run the `generate.sh` to automatically generate all tests files:

```bash
./generate.sh
```

Finally run the tests:

```bash
cargo test
```

## License

This website is licensed under [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication][cc].

[![CC BY-SA 4.0][cc-image]][cc]

[cc]: https://creativecommons.org/publicdomain/zero/1.0/
[cc-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-shield]: https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg
