# BioStockholm.jl

Julia parser for the Stockholm file format (.sto) used for multiple
sequence alignments (Pfam, Rfam, etc).

## Installation

As the package is not yet registered in the Julia registry, you have
to install it from github by typing this into the Julia REPL:

```
] add https://github.com/marcom/BioStockholm.jl
```

## Usage

```julia
using BioStockholm
sto = parse(Stockholm, sto_str)
print(sto)
```

## Related packages

[MIToS.jl](https://github.com/diegozea/MIToS.jl) is a package for
analysing protein sequences that also supports parsing the Stockholm
format and many things more.
