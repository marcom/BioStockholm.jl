using Test
using BioStockholm
using OrderedCollections: OrderedDict
const ODict = OrderedDict

# TODO
# - test that correct data is stored

# example Stockholm alignment files
example_sto1 = read("example1.sto", String)
example_sto2 = read("example2.sto", String)

@testset "constructors" begin
    seq = ODict("seq1" => "AAAGGG")
    GF  = ODict("feature1" => "some text",
                "feature2" => "some more text")
    GS  = ODict("seq1" => ODict("feat1" => "text1", "feat2" => "text2"))
    GR  = ODict("seq1" => ODict("feat1" => "---xxx", "feat2" => "EEECCC"))
    GC  = ODict("feat" => "oxoxox")

    @test Stockholm() isa Stockholm{String}
    @test Stockholm(; seq, GF, GS, GR, GC) isa Stockholm{String}

    for T in [String, Vector{UInt8}, Vector{Char}]
        s = ODict(k => T(v) for (k,v) in seq)
        gr = ODict(k => ODict(f => T(s) for (f,s) in d) for (k,d) in GR)
        gc = ODict(k => T(v) for (k,v) in GC)
        @test Stockholm{T}() isa Stockholm{T}
        @test Stockholm{T}(; seq=s, GF, GS, GR=gr, GC=gc) isa Stockholm{T}
    end
end

@testset "parse" begin
    for sto_str in [example_sto1, example_sto2]
        sto = parse(Stockholm, sto_str)
        @test length(sto.seq) > 0

        for T in [String]
            sto = parse(Stockholm{T}, sto_str)
            @test length(sto.seq) > 0
        end

        # broken tests
        for T in [Vector{UInt8}, Vector{Char}]
            @test_broken length(parse(Stockholm{T}, sto_str).seq) > 0
        end
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

        for T in [String]
            sto_read = read(path, Stockholm{T})
            @test sto_read == sto
        end
    end
end
