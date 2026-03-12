Bitcoin amounts are usually expressed in BTC or satoshis (sats), 
where 1 BTC = 100,000,000 sats.
Beyond the satoshi, payment channels might use even smaller units such as millibitcoins (mBTC) to represent more granular amounts.

The `Amount` type represents a non-negative bitcoin amount, stored internally 
as satoshis — all amounts in `rust-bitcoin` are denominated in satoshi before 
they are converted for display. For cases where we need a negative value, 
`rust-bitcoin` provides the `SignedAmount` type.

We provide the following examples:
- [Amount](units/amount.md)
- [NumOpResult](units/numopresult.md)
- [Calculating fees](units/fees.md)
- [Lock times](units/locktimes.md)
