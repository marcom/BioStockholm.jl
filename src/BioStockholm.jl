module BioStockholm

# Stockholm format for multiple sequence alignments (MSA)
#   https://sonnhammer.sbc.su.se/Stockholm.html
#   https://en.wikipedia.org/wiki/Stockholm_format

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp
using OrderedCollections: OrderedDict

export MSA

# TODO
# - collect data as Vector{Char} or Vector{UInt8} instead of as String?
#   - avoids excessive string concatenation

# Automa automatic vars (from Automa.generate_init_code())
#   - p: index into data currently being read
#   - cs: current state of state machine (FSM), 0 is accept, 1 is start
#   - p_end
#   - p_eof

"""
    MSA{T}

Stockholm format for multiple sequence alignment with
annotations. Sequence data is of type `Vector{T}`.

## Examples
```julia
using BioStockholm
msa = read(msa_filepath::String, MSA)
msa = parse(MSA, msa_str::String)
msa = parse(MSA{UInt8}, msa_str::String)
write("out.sto", msa)
print(msa)

msa = MSA{Char}(;
    seq = Dict("human"   => "ACACGCGAAA.GCGCAA.CAAACGUGCACGG",
               "chimp"   => "GAAUGUGAAAAACACCA.CUCUUGAGGACCU",
               "bigfoot" => "UUGAG.UUCG..CUCGUUUUCUCGAGUACAC"),
     GC = Dict("SS_cons" => "...<<<.....>>>....<<....>>.....")
)
```

## Fields
```
seq: seqname => seqdata
GF : per_file_feature => text
GS : seqname => per_seq_feature => text
GC : per_file_feature => seqdata
GR : seqname => per_seq_feature => seqdata
```
"""
Base.@kwdef struct MSA{T}
    # seqname => seqdata
    seq :: OrderedDict{String, Vector{T}} =
        OrderedDict{String, Vector{T}}()
    # per_file_feature => text
    GF  :: OrderedDict{String, String} =
        OrderedDict{String, String}()
    # seqname => per_seq_feature => text
    GS  :: OrderedDict{String, OrderedDict{String, String}} =
        OrderedDict{String, OrderedDict{String, String}}()
    # per_file_feature => seqdata
    GC  :: OrderedDict{String, Vector{T}} =
        OrderedDict{String, Vector{T}}()
    # seqname => per_seq_feature => seqdata
    GR  :: OrderedDict{String, OrderedDict{String, Vector{T}}} =
        OrderedDict{String, OrderedDict{String, Vector{T}}}()

    function MSA{T}(seq, GF, GS, GC, GR) where {T}
        if valtype(seq) === String
            seq = OrderedDict(name => T.(collect(s)) for (name,s) in seq)
        end
        if valtype(GC) === String
            GC = OrderedDict(feat => T.(collect(s)) for (feat,s) in GC)
        end
        if valtype(valtype(GR)) === String
            GR = OrderedDict(name => OrderedDict(feat => T.(collect(s)) for (feat,s) in f2s) for (name,f2s) in GR)
        end
        return new{T}(seq, GF, GS, GC, GR)
    end
end

function Base.:(==)(s1::MSA, s2::MSA)
    return (s1.seq == s2.seq
            && s1.GF == s2.GF
            && s1.GS == s2.GS
            && s1.GC == s2.GC
            && s1.GR == s2.GR)
end

function Base.show(io::IO, mime::MIME"text/plain", msa::MSA)
    show(io, mime, typeof(msa))
    println(" with $(length(msa.seq)) sequences")
    println(io, "seq")
    print(io, " ")
    show(io, mime, msa.seq)
    println(io, "\nGF")
    print(io, " ")
    show(io, mime, msa.GF)
    println(io, "\nGS")
    print(io, " ")
    show(io, mime, msa.GS)
    println(io, "\nGR")
    print(io, " ")
    show(io, mime, msa.GR)
    println(io, "\nGC")
    print(io, " ")
    show(io, mime, msa.GC)
end

const stockholm_machine = let
    nl      = re"\r?\n"
    ws      = re"[ \t]+"
    feature = re"[^ \t\n]+"
    seqname = re"[^# \t\n][^ \t\n]*"
    text    = re"[^\n]*"
    seqdata = re"[^ \t\n]+"

    line_header = re"# STOCKHOLM 1.0" * nl
    line_end    = re"//" * nl
    line_GF     = re"#=GF" * ws * feature * ws * text * nl
    line_GC     = re"#=GC" * ws * feature * ws * seqdata * nl
    line_GS     = re"#=GS" * ws * seqname * ws * feature * ws * text * nl
    line_GR     = re"#=GR" * ws * seqname * ws * feature * ws * seqdata * nl
    line_seq    = seqname * ws * seqdata * nl
    line_empty  = re"[ \t]*" * nl

    stockholm = (
        re.rep(line_empty)
        * line_header
        * re.rep(line_GF | line_GC | line_GS | line_GR | line_seq | line_empty)
        * line_end
    )

    nl.actions[:enter]      = [:countline]
    feature.actions[:enter] = [:enter_feature]
    feature.actions[:exit]  = [:feature]
    seqname.actions[:enter] = [:enter_seqname]
    seqname.actions[:exit]  = [:seqname]
    text.actions[:enter]    = [:enter_text]
    text.actions[:exit]     = [:text]
    seqdata.actions[:enter] = [:enter_seqdata]
    seqdata.actions[:exit]  = [:seqdata]
    line_GF.actions[:exit]  = [:line_GF]
    line_GC.actions[:exit]  = [:line_GC]
    line_GS.actions[:exit]  = [:line_GS]
    line_GR.actions[:exit]  = [:line_GR]
    line_seq.actions[:exit] = [:line_seq]

    Automa.compile(stockholm)
end

const stockholm_actions = Dict(
    :countline => :(linenum += 1),

    :enter_feature => :(mark = p),
    :enter_seqname => :(mark = p),
    :enter_text    => :(mark = p),
    :enter_seqdata => :(mark = p),

    :feature => :(feature = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :seqname => :(seqname = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :text    => :(text = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :seqdata => :(seqdata = mark == 0 ? T[] : T.(collect(data[mark:p-1])); mark = 0),

    :line_GF => quote
        if haskey(gf_records, feature)
            gf_records[feature] *= " " * text
        else
            gf_records[feature] = text
        end
    end,
    :line_GC => :(
        # gc_records[feature] = get(gc_records, feature, "") * seqdata
        gc_records[feature] = append!(get(gc_records, feature, T[]), seqdata)
    ),
    :line_GS => quote
        if haskey(gs_records, seqname)
            if haskey(gs_records[seqname], feature)
                gs_records[seqname][feature] *= " " * text
            else
                gs_records[seqname][feature] = text
            end
        else
            gs_records[seqname] = OrderedDict(feature => text)
        end
    end,
    :line_GR => quote
        if haskey(gr_records, seqname)
            # gr_records[seqname][feature] = get(gr_records[seqname], feature, "") * seqdata
            gr_records[seqname][feature] = append!(get(gr_records[seqname], feature, T[]), seqdata)
        else
            gr_records[seqname] = OrderedDict(feature => seqdata)
        end
    end,
    :line_seq => :(
        sequences[seqname] = append!(get(sequences, seqname, T[]), seqdata)
    ),
)

Base.read(io::IO, ::Type{MSA{T}}) where {T} =
    parse(MSA, read(io, String))

Base.read(io::IO, ::Type{MSA}) =
    read(io, MSA{Char})

Base.read(filepath::AbstractString, ::Type{MSA{T}}) where {T} =
    open(filepath) do io
        read(io, MSA)
    end

Base.read(filepath::AbstractString, ::Type{MSA}) =
    read(filepath, MSA{String})

Base.write(io::IO, msa::MSA) =
    print(io, msa)

Base.write(filepath::AbstractString, msa::MSA) =
    open(filepath, "w") do io
        print(io, msa)
    end

Base.parse(::Type{MSA}, data::Union{String,Vector{UInt8}}) =
    parse_stockholm(Char, data)

Base.parse(::Type{MSA{T}}, data::Union{String,Vector{UInt8}}) where {T} =
    parse_stockholm(T, data)

const context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function parse_stockholm(::Type{T}, data::Union{String,Vector{UInt8}}) where {T}
    # variables for the action code
    sequences  = OrderedDict{String,Vector{T}}()                        # seqname => seqdata
    gf_records = OrderedDict{String,String}()                           # feature => text
    gc_records = OrderedDict{String,Vector{T}}()                        # feature => seqdata
    gs_records = OrderedDict{String,OrderedDict{String,String}}()       # seqname => feature => text
    gr_records = OrderedDict{String,OrderedDict{String,Vector{T}}}()    # seqname => feature => seqdata
    linenum = 1
    mark = 0
    seqname = ""
    feature = ""
    text = ""
    seqdata = ""

    # init vars for state machine
    $(Automa.generate_init_code(context, stockholm_machine))
    p_end = p_eof = lastindex(data)

    # main loop over input data
    $(Automa.generate_exec_code(context, stockholm_machine, stockholm_actions))

    if cs != 0
        error("failed to parse on line ", linenum)
    end

    return MSA{T}(; seq=sequences, GF=gf_records, GC=gc_records,
                  GS=gs_records, GR=gr_records)
end

Base.print(msa::MSA) = print(stdout, msa)

function Base.print(io::IO, msa::MSA)
    # TODO: split long lines
    str(a) = String(a)
    str(a::Vector{UInt8}) = String(copy(a))

    println(io, "# STOCKHOLM 1.0")
    # GF: feature => text
    max_len = maximum(length(f) for (f,_) in msa.GF; init=0)
    for (feature, text) in msa.GF
        indent = repeat(" ", max_len - length(feature))
        println(io, "#=GF $feature    $(indent)$(text)")
    end
    # GS: seqname => feature => text
    # TODO: align seqname / feature when printing
    max_desc_len = maximum(length(sn) + length(f) for (sn,f2t) in msa.GS for (f,_) in f2t; init=0)
    for (seqname, feature_to_text) in msa.GS
        for (feature, text) in feature_to_text
            indent = repeat(" ", max_desc_len - (length(seqname) + length(feature)))
            println(io, "#=GS $seqname $feature    $(indent)$(text)")
        end
    end
    max_len = max(
        maximum(length(sn) for (sn,_) in msa.seq; init=0),
        # +1 for extra space char
        maximum(length(sn) + length(f) + 1 for (sn,f2t) in msa.GR for (f,_) in f2t; init=0),
        maximum(length(f) for (f,_) in msa.GC; init=0)
    )
    println(io)
    # seq: seqname => seqdata
    for (seqname, s) in msa.seq
        # + 5 for missing "#=GX "
        indent = repeat(" ", max_len - length(seqname) + 5)
        println(io, "$seqname    $(indent)$(str(s))")
        # GR: seqname => feature => seqdata
        if haskey(msa.GR, seqname)
            for (feature, r) in msa.GR[seqname]
                # +1 for extra space char
                indent = repeat(" ", max_len - (length(seqname) + length(feature) + 1))
                println(io, "#=GR $seqname $feature    $(indent)$(str(r))")
            end
        end
    end
    # GC: feature => seqdata
    for (feature, c) in msa.GC
        indent = repeat(" ", max_len - length(feature))
        println(io, "#=GC $feature    $(indent)$(str(c))")
    end
    println(io, "//")
end

end # module BioStockholm
