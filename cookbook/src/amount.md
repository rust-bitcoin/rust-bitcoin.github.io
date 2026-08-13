# Parsing and Formatting Amounts

`Amount` represents a non-negative Bitcoin amount with satoshi precision. Parse a
string with its denomination, then choose the denomination when formatting it:

```rust
use bitcoin::{amount::Denomination, Amount};

fn main() -> Result<(), bitcoin::amount::ParseError> {
    let amount = "0.1 BTC".parse::<Amount>()?;
    assert_eq!(amount.to_sat(), 10_000_000);

    assert_eq!(amount.to_string_in(Denomination::Bitcoin), "0.1");
    assert_eq!(amount.to_string_with_denomination(Denomination::Satoshi), "10000000 sat");

    println!("{amount}");
    Ok(())
}
```

The input includes `BTC`, while the formatting methods make the output
denomination explicit. `to_string_in` omits the denomination and
`to_string_with_denomination` includes it.
