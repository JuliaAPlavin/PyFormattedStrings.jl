# PyFormattedStrings.jl

Python-style `f`-strings for Julia.

See [PEP 498](https://www.python.org/dev/peps/pep-0498/) for the original Python `f`-strings feature. \
Mirrors Python behavior as closely as possible – formatting is performed by the `Printf` stdlib, this package converts the syntax. Zero overhead compared to a manually-written `@printf` call.

```julia
using PyFormattedStrings

# Basic interpolation
name, score = "Alice", 95.7
f"Player {name} scored {score:.1f} points"    # "Player Alice scored 95.7 points"

# Arbitrary expressions inside braces
a, b = 10, 3
f"{a} / {b} = {a/b:.2f}"                      # "10 / 3 = 3.33"

# Works with any Julia expression
f"Result: {sum([1, 2, 3]) * 2:d}"             # "Result: 12"
```

### Format specs

All standard Printf formats work: width, precision, alignment, padding, hex, etc.

```julia
# Alignment and padding
price = 42
f"Price: ${price:>6d}"              # "Price: $    42"
f"Item{1:<4d}qty{10:>5d}"           # "Item1   qty   10"

# Number formatting
pi_approx = 3.14159
f"π ≈ {pi_approx:.2f}"              # "π ≈ 3.14"
f"{255:#x}"                         # "0xff"

# Zero padding
iteration = 5
f"file_{iteration:04d}.dat"         # "file_0005.dat"

# Dynamic width and precision
value, width, prec = 123.456, 10, 2
f"Value: {value:{width}.{prec}f}"   # "Value:     123.46"
```

### Reusable format functions

Create formatting functions with `ff"..."` for repeated use:

```julia
# Named fields from named tuples
report = ff"[{level:>5s}] {message}"
report((level="INFO", message="Starting process"))   # "[INFO] Starting process"
report((level="ERROR", message="Failed"))            # "[ERROR] Failed"

# Access properties of the argument
fmt_complex = ff"{re:.2f} + {im:.2f}i"
fmt_complex(3.14159 + 2.71828im)                     # "3.14 + 2.72i"

# Single-argument forms (useful for map, broadcast, etc.)
formatter = ff"{:.1f}%"
formatter.(90:5:100)                                 # ["90.0%", "95.0%", "100.0%"]
```

### Limitations

Compared to Python, these features are not implemented yet: (1) postfix modifiers (`!a`, `!s`, `!r`), (2) `=` and `^` alignment options, (3) `=` sign to show expression.
