# Amount

In this section, we will demonstrate different ways of working with Bitcoin amounts using the `Amount` type. The examples in this section will:

- Justify the MAX 21 million decision
- Demonstrate parsing and formatting strings
- Show basic best practices for `NumOpResult` (more complex explanation [here])

**The 21 Million Bitcoin Limit**

Only 21 million Bitcoins will ever be in circulation. This number is hardcoded in the Bitcoin protocol.
The logic behind this decision is to create scarcity and protect Bitcoin against inflation as the digital gold.
Bitcoin is distributed as a result of mining a block and after every 210,000 blocks, the reward is halved and the complexity increases. The first reward was 50 BTC, so:

50 + 25 + 12.5 + 6.25 + 3.125 + 1.5625 + … + 0.000000001 ≈ 100 (almost)

210,000 blocks × 100 BTC (sum of geometric series) = 21,000,000 BTC

The last Bitcoin should be mined at around year 2140.

Bitcoin further scales down to smaller units like satoshis (sats).
1 BTC = 100,000,000 sats.
This makes micro-transactions easy despite the high price of a single coin.

**Setup**

If using `rust-bitcoin`, `Amount` is exported:
```rust
use bitcoin::Amount;
```

Or use the units crate directly:
```bash
cargo add bitcoin-units
```
```rust
use bitcoin_units::Amount;
```

For this example, we are going to need this import:
```rust
use bitcoin_units::{amount::Denomination, Amount};
```
Everything else goes into the main function.
```rust
fn main() {
    // The 21 million cap
    let max = Amount::MAX;
    println!("Maximum amount: {} satoshis", max.to_sat());
    println!("Maximum amount: {}", max.display_in(Denomination::Bitcoin).show_denomination());

    // Exceeding the cap returns an error
    let too_big = Amount::from_sat(Amount::MAX.to_sat() + 1);
    println!("Exceeding MAX: {:?}", too_big); // Err(OutOfRangeError)

    // Handling constants - no result handling needed
    let one_btc = Amount::ONE_BTC;
    println!("One BTC = {} satoshis", one_btc.to_sat());

    let zero = Amount::ZERO;
    println!("Zero amount: {} satoshis", zero.to_sat());

    // No result handling for small amounts
    let small = Amount::from_sat_u32(50_000);
    println!("Small Amount = {}", small);

    // Result handling for larger amounts
    let large = Amount::from_sat(100_000_000).expect("valid amount");
    println!("Large Amount = {}", large);

    // Parsing string type to Amount - result handling needed for potential error
    let amount1: Amount = "0.1 BTC".parse().expect("valid amount");
    println!("Amount1 parsed: {}", amount1);
    let amount2 = "100 sat".parse::<Amount>().expect("valid");
    println!("Amount2 parsed: {}", amount2);

    // Formatting with display_in (works without alloc)
    println!("Display in BTC: {}", Amount::ONE_BTC.display_in(Denomination::Bitcoin));
    println!("Display in Satoshi: {}", Amount::ONE_SAT.display_in(Denomination::Satoshi));
    println!(
        "Display in BTC with denomination: {}",
        Amount::ONE_BTC.display_in(Denomination::Bitcoin).show_denomination()
    );
    println!(
        "Display in Satoshi with denomination: {}",
        Amount::ONE_SAT.display_in(Denomination::Satoshi).show_denomination()
    );

    // display_dynamic automatically selects denomination
    println!("Display dynamic: {}", Amount::ONE_SAT.display_dynamic()); // shows in satoshis
    println!("Display dynamic: {}", Amount::ONE_BTC.display_dynamic()); // shows in BTC

    // to_string_in and to_string_with_denomination require alloc feature
    #[cfg(feature = "alloc")]
    {
        println!("to_string_in: {}", Amount::ONE_BTC.to_string_in(Denomination::Bitcoin));
        println!(
            "to_string_with_denomination: {}",
            Amount::ONE_SAT.to_string_with_denomination(Denomination::Satoshi)
        );
    }

    // Arithmetic operations return NumOpResult
    let a = Amount::from_sat(1000).expect("valid");
    let b = Amount::from_sat(500).expect("valid");

    let sum = a + b; // Returns NumOpResult<Amount>
    println!("Sum = {:?}", sum);

    // Extract the value using .unwrap()
    let sum_amount = (a + b).unwrap();
    println!("Sum amount: {} satoshis", sum_amount.to_sat());

    // Error in case of a negative result
    let tiny = Amount::from_sat(100).expect("valid");
    let big = Amount::from_sat(1000).expect("valid");
    let difference = tiny - big;
    println!("Underflow result: {:?}", difference);
}
```

**Creating Amounts**

There are different ways of creating and representing amounts.
The 21 million cap is represented using the `MAX` constant.
This constant is used to validate inputs, set logic boundaries, and implement 
sanity checks when testing. It is also more readable compared to hardcoding 
the full 21 million amount.

`from_sat_u32` accepts a `u32`, which is small enough to always be within the 
valid range, so no result handling is needed. `from_sat` accepts a `u64` which 
can exceed the 21 million cap, hence the `Result`.

The `Denomination` enum specifies which unit to display the value in. When you 
call `show_denomination()`, it prints the unit alongside the value. When the 
amount exceeds 21 million, it throws an out-of-range error. Other constants used to represent Bitcoin amounts include `ONE_SAT`, `ONE_BTC`, 
`FIFTY_BTC`, and `ZERO`.

**Parsing and Formatting**

When parsing small amounts, result handling is not strictly necessary unless 
you want extra caution. We use `.expect()` to handle results for larger amounts.
The `rust-bitcoin` library also allows us to parse amounts as strings and output 
them as `Amount` using the `parse` method. Error handling is necessary in this case.

When formatting output, the preferred method is `.display_in()`. It can be 
combined with `fmt::Formatter` options to precisely control zeros, padding, and 
alignment — similar to how floats work in `core`, except that it's more precise, 
meaning no rounding occurs. It also works without `alloc`, making it suitable for 
`no_std` environments such as hardware wallets or embedded signing devices.

Alternatively, `.display_dynamic()` automatically selects the denomination — 
displaying in BTC for amounts greater than or equal to 1 BTC, and in satoshis 
otherwise. The denomination is always shown to avoid ambiguity.

If you need a `String` directly, `.to_string_in()` outputs just the number and 
`.to_string_with_denomination()` includes the units. These are convenience wrappers 
around `.display_in()` and require the `alloc` feature.

Note that the exact formatting behaviour of `.display_in()` may change between 
versions, though it guarantees accurate human-readable output that round-trips 
with `parse`.

**NumOpResult**

Performing arithmetic operations produces a `NumOpResult`, which we discuss in more detail [here].
All you need to understand for now is that arithmetic on amounts does not panic in case of errors — instead it returns `Valid(Amount)` on success and `Error` on failure.
We therefore explicitly extract the result using `.unwrap()` or other proper error handling options.