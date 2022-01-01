# Overview

Julia implementation of Python-like _formatted string literals_ or _f-strings_. Mirrors the corresponding Python behavior as closely as possible without reimplementing formatting from scratch. Actual formatting is performed by the `Printf` stdlib, this package just converts the formatted string syntax. There should be no additional runtime overhead compared to a manually-written corresponding @printf call.

Motivation is effectively the same as for f-strings in Python: see https://www.python.org/dev/peps/pep-0498/ for background.

# Examples

```jldoctest label
julia> using PyFormattedStrings
```
```jldoctest label
julia> x = 5.123;

julia> f"{x}"
"5.123"

julia> f"value is now {x:.1f}"
"value is now 5.1"

julia> f"fraction of {x:d}%"
"fraction of 5%"
```

# Notable differences from Python

## Not supported

* Postfix modifiers (`!a`, `!s`, `!r`)
* `=` and `^` alignment options
* Alternate form for conversion (`#`)
* `=` sign to show expression
