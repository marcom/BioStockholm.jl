using Test
using BioStockholm: parse_stockholm, print_stockholm

# TODO
# - test that correct data is stored

# example_sto1, example_sto2
include("example_data.jl")

@testset "parse_stockholm" begin
    for sto in [example_sto1, example_sto2]
        s, gf, gc, gs, gr = parse_stockholm(sto)
        @test length(s) > 0
    end
end

@testset "print_stockholm" begin
    gf  = Dict("FOO"    => "some text",
               "BARBAZ" => "some more text")
    gs  = Dict("Seq1/1.1"  => Dict("Prop1"     => "some text for property"),
               "Seq2/2.11" => Dict("Property2" => "even more text"))

    seq = Dict("Seq1/1.1"                   => "GGGAAACCC",
               "Seq2/2.11"                  => "UUGAGACCA")
    gr  = Dict("Seq1/1.1"  => Dict("foo"    => "EEGHHHEEC",
                                   "barbaz" => "...---..."),
               "Seq2/2.11" => Dict("foo"    => "HHEEEEECE"))
    gc  = Dict("FOO"                        => "(((...)))",
               "FOOBAR"                     => "+--...--+")

    iobuf = IOBuffer()
    print_stockholm(iobuf; seq, gf, gc, gs, gr)
    out = String(take!(iobuf))
    @test length(out) > 0
end
