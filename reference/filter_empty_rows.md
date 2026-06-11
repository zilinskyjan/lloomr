# Drop rows whose text column is missing or empty

Mirrors `filter_empty_rows()` upstream: removes rows where the given
column is `NA` or a zero-length string.

## Usage

``` r
filter_empty_rows(df, text_col)
```

## Arguments

- df:

  A data frame.

- text_col:

  Name of the text column (string).

## Value

The filtered data frame.

## Examples

``` r
df <- data.frame(id = 1:3, text = c("keep me", "", NA))
filter_empty_rows(df, "text")
#>   id    text
#> 1  1 keep me
```
