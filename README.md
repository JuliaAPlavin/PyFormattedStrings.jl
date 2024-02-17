# Overview

Julia implementation of Python-like _formatted string literals_ or _f-strings_. See [PEP 498](https://www.python.org/dev/peps/pep-0498/) for the original motivation and background for f-strings in Python.

`PyFormattedStrings.jl` mirrors the corresponding Python behavior as closely as possible without reimplementing formatting from scratch. Actual formatting is performed by the `Printf` stdlib, this package just converts the formatted string syntax. There is no additional runtime overhead compared to a manually-written corresponding `@printf` call.

Supports all f-string features that are directly available in `Printf`. Compared to Python, these are not implemented: (1) postfix modifiers (`!a`, `!s`, `!r`), (2)  `=` and `^` alignment options, (3) `=` sign to show expression.



# Examples

```julia
julia> using PyFormattedStrings
```

```julia
julia> x = 5.123

julia> f"{x}"
"5.123"

julia> f"value is now {x:.1f}"
"value is now 5.1"

julia> f"fraction of {(x-5)*100:d}%"
"fraction of 12%"
```

With the `ff"..."` syntax, the formatting string can be created ahead of time and applied to values later:
```julia
julia> fmtfunc = ff"value a={a:.2f} and first b={first(b):d}"

julia> fmtfunc((a=1, b=[2, 3]))
"value a=1.00 and first b=2"

julia> fmtfunc = ff"{re:.2f} {im:d}"

julia> fmtfunc(1.234 + 5.678im)
"1.23 6"
```
