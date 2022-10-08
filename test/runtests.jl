using Test
using BioStockholm
using OrderedCollections: OrderedDict
const ODict = OrderedDict

# TODO
# - test that correct data is stored

# example Stockholm alignment files
example_sto1 = read("example1.sto", String)
example_sto2 = read("example2.sto", String)

@testset "parse" begin
    for sto_str in [example_sto1, example_sto2]
        sto = parse(Stockholm, sto_str)
        @test length(sto.seq) > 0
    end
end

@testset "print" begin
    sto = Stockholm{String}(;
        GF  = ODict("FOO"    => "some text",
                    "BARBAZ" => "some more text"),
        GS  = ODict("Seq1/1.1"  => ODict("Prop1"     => "some text for property"),
                    "Seq2/2.11" => ODict("Property2" => "even more text")),
        seq = ODict("Seq1/1.1"                    => "GGGAAACCC",
                    "Seq2/2.11"                   => "UUGAGACCA"),
        GR  = ODict("Seq1/1.1"  => ODict("foo"    => "EEGHHHEEC",
                                         "barbaz" => "...---..."),
                    "Seq2/2.11" => ODict("foo"    => "HHEEEEECE")),
        GC  = ODict("FOO"                         => "(((...)))",
                    "FOOBAR"                      => "+--...--+")
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
