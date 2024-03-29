using Test
using BioStockholm
using OrderedCollections: OrderedDict
const ODict = OrderedDict

# show which testset is currently running
showtestset() = println(" "^(2 * Test.get_testset_depth()), "testing ",
                        Test.get_testset().description)

lf2crlf(s::AbstractString) = replace(s, "\n" => "\r\n")

# example Stockholm alignment files
example_msa1 = read("example1.sto", String)
example_msa2 = read("example2.sto", String)

@testset verbose=true "BioStockholm" begin
    showtestset()
    include("aqua.jl")

    @testset "constructors" begin
        showtestset()
        seq = ODict("seq1" => "AAAGGG")
        GF  = ODict("feature1" => "some text",
                    "feature2" => "some more text")
        GS  = ODict("seq1" => ODict("feat1" => "text1", "feat2" => "text2"))
        GR  = ODict("seq1" => ODict("feat1" => "---xxx", "feat2" => "EEECCC"))
        GC  = ODict("feat" => "oxoxox")

        for T in (UInt8, Char)
            @test MSA{T}() isa MSA{T}
            @test MSA{T}(; seq, GF, GS, GR, GC) isa MSA{T}
        end
    end

    @testset "parse" begin
        showtestset()
        for msa_str in [example_msa1, example_msa2]
            msa = parse(MSA, msa_str)
            @test length(msa.seq) > 0
            # test that changing LF to CRLF line endings parses the same
            @test parse(MSA, lf2crlf(msa_str)) == msa

            for T in (UInt8, Char)
                msa = parse(MSA{T}, msa_str)
                @test length(msa.seq) > 0
                # test that changing LF to CRLF line endings parses the same
                @test parse(MSA{T}, lf2crlf(msa_str)) == msa
            end
        end
    end

    @testset "print" begin
        showtestset()
        for T in (UInt8, Char)
            msas = [
                MSA{T}(;
                       GF  = ODict("FOO"    => "some text",
                                   "BARBAZ" => "some more text"),
                       GS  = ODict("Seq1/1.1"  => ODict("Prop1"     => "some text for property" * repeat(" X", 100)),
                                   "Seq2/2.11" => ODict("Property2" => "even more text" * repeat(" Y", 100))),
                       seq = ODict("Seq1/1.1"                    => "GGGAAACCC",
                                   "Seq2/2.11"                   => "UUGAGACCA"),
                       GR  = ODict("Seq1/1.1"  => ODict("foo"    => "EEGHHHEEC",
                                                        "barbaz" => "...---..."),
                                   "Seq2/2.11" => ODict("foo"    => "HHEEEEECE")),
                       GC  = ODict("FOO"                         => "(((...)))",
                                   "FOOBAR"                      => "+--...--+")
                       ),
                parse(MSA{T}, example_msa1),
                parse(MSA{T}, example_msa2)
            ]
            for msa in msas
                iobuf = IOBuffer()
                print(iobuf, msa)
                out = String(take!(iobuf))
                @test length(out) > 0
                msa2 = parse(MSA{T}, out)
                @test msa2 == msa
            end
        end
    end

    @testset "write" begin
        showtestset()
        msa = parse(MSA, example_msa1)

        mktemp() do path, io
            write(io, msa)
            close(io)
            @test isfile(path)
            @test filesize(path) > 0
        end

        mktemp() do path, io
            write(path, msa)
            @test isfile(path)
            @test filesize(path) > 0
        end
    end

    @testset "read" begin
        showtestset()
        msa = parse(MSA, example_msa1)

        mktemp() do path, io
            write(path, msa)

            msa_read = read(path, MSA)
            @test msa_read == msa

            for T in [String]
                msa_read = read(path, MSA{T})
                @test msa_read == msa
            end
        end
    end

end
