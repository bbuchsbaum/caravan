# Split grid row positions into groups without losing missing values.

[`interaction()`](https://rdrr.io/r/base/interaction.html) assigns `NA`
to rows with missing grouping values, and
[`split()`](https://rdrr.io/r/base/split.html) then omits those rows.
vctrs groups missing values as keys.

## Usage

``` r
.parade_group_rows(grid, by = character())
```
