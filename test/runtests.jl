using Test
using BioStockholm: parse_stockholm

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
