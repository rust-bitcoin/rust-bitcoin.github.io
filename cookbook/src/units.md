Bitcoin is majorly expressed as BTC(bitcoins), mBTC(millibitcoins), sats(satoshis) or bits.
The BTC unit represents a 10^8 value so as to have sub-unit precision instead of large whole numbers.
This allows divisions of 1/10th, 1/100th and so on.

The satoshi, named after the original bitcoin creator, Satoshi Nakamoto, is the smallest unit of bitcoin currency representing a hundred millionth of one Bitcoin (0.00000001 BTC).

The Bitcoin source code uses satoshi to specify any Bitcoin amount and all amounts on the blockchain are denominated in satoshi before they get converted for display.

Amounts can also be represented using satoshis to enhance readability when handling extremely fine bitcoin fractions like when handling fees or faucet rewards.

Beyond Satoshi, payment channels might use even smaller units such as millisatoshis (one hundred billionths of a bitcoin) to represent even more granular amounts.

The `Amount` type represents a non-negative Bitcoin amount, stored internally 
as satoshis. For cases where a negative value is needed, `rust-bitcoin` provides 
the `SignedAmount` type.

We provide the following examples:
- [Amount](units/amount.md)
- [NumOpResult](units/numopresult.md)
- [Calculating fees](units/fees.md)
- [Lock times](units/locktimes.md)