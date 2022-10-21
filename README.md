# BioStockholm.jl

Julia parser for the [Stockholm file
format](https://en.wikipedia.org/wiki/Stockholm_format) (.sto) used
for multiple sequence alignments (Pfam, Rfam, etc).  This package uses
[Automa.jl](https://github.com/BioJulia/Automa.jl) under the hood to
generate a finite state machine parser.


## Installation

```
using Pkg
pkg"add https://github.com/marcom/BioStockholm.jl"
```


## Usage

```julia
using BioStockholm

# example2.sto contains an example Stockholm file
msa_path = joinpath(dirname(pathof(BioStockholm)), "..",
                    "test", "example2.sto")
msa_str = read(msa_path, String)
print(msa_str)

# read from a file or parse from a String
msa = read(msa_path, MSA)
msa = parse(MSA, msa_str)

# write to a file
write("foobar.sto", msa)

# pretty-print
print(msa)
print(stdout, msa)
```


## Limitations / TODO
- when writing, long sequences or text is never split over multiple lines
- integrate with BioJulia string types


## Related packages

[MIToS.jl](https://github.com/diegozea/MIToS.jl) is a package for
analysing protein sequences that also supports parsing the Stockholm
format (and many more things).
