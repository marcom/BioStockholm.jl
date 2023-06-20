# BioStockholm.jl

[![Build Status](https://github.com/marcom/BioStockholm.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/marcom/BioStockholm.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Julia parser for the [Stockholm file
format](https://en.wikipedia.org/wiki/Stockholm_format) (.sto) used
for multiple sequence alignments (Pfam, Rfam, etc).  This package uses
[Automa.jl](https://github.com/BioJulia/Automa.jl) under the hood to
generate a finite state machine parser.


## Installation

Enter the package mode from the Julia REPL by pressing `]`, then
install with:

```
add BioStockholm
```


## Usage

```julia
using BioStockholm

msa = MSA{Char}(;
    seq = Dict("human"   => "ACACGCGAAA.GCGCAA.CAAACGUGCACGG",
               "chimp"   => "GAAUGUGAAAAACACCA.CUCUUGAGGACCU",
               "bigfoot" => "UUGAG.UUCG..CUCGUUUUCUCGAGUACAC"),
     GC = Dict("SS_cons" => "...<<<.....>>>....<<....>>.....")
)

# read from file
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
