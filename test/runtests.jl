using Test
using BioStockholm

# TODO
# - test that correct data is stored

# example_sto1, example_sto2
include("example_data.jl")

@testset "parse" begin
    for sto_str in [example_sto1, example_sto2]
        sto = parse(Stockholm, sto_str)
        @test length(sto.seq) > 0
    end
end

@testset "print" begin
    sto = Stockholm{String}(;
        GF  = Dict("FOO"    => "some text",
                   "BARBAZ" => "some more text"),
        GS  = Dict("Seq1/1.1"  => Dict("Prop1"     => "some text for property"),
                   "Seq2/2.11" => Dict("Property2" => "even more text")),
        seq = Dict("Seq1/1.1"                   => "GGGAAACCC",
                   "Seq2/2.11"                  => "UUGAGACCA"),
        GR  = Dict("Seq1/1.1"  => Dict("foo"    => "EEGHHHEEC",
                                       "barbaz" => "...---..."),
                   "Seq2/2.11" => Dict("foo"    => "HHEEEEECE")),
        GC  = Dict("FOO"                        => "(((...)))",
                   "FOOBAR"                     => "+--...--+")
    )
    iobuf = IOBuffer()
    print(iobuf, sto)
    out = String(take!(iobuf))
    @test length(out) > 0
end

@testset "write" begin
    sto = parse(Stockholm, example_sto1)

    mktemp() do path, io
        write(io, sto)
        close(io)
        @test isfile(path)
        @test filesize(path) > 0
    end

    mktemp() do path, io
        write(path, sto)
        @test isfile(path)
        @test filesize(path) > 0
    end
end

@testset "read" begin
    sto = parse(Stockholm, example_sto1)

    mktemp() do path, io
        write(path, sto)
        sto_read = read(path, Stockholm)
        @test sto_read == sto
    end
end
