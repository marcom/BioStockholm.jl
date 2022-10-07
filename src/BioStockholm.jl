module BioStockholm

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

export Stockholm

# TODO
# - collect data as Vector{Char} or Vector{UInt8} instead of as String?
#   - avoids excessive string concatenation

# Notes on Automa
# - automatic vars (from Automa.generate_init_code())
#   - p: index into data currently being read
#   - cs: current state of state machine (FSM), 0 is accept, 1 is start
#   - p_end
#   - p_eof


Base.@kwdef struct Stockholm{Tseq}
    # seqname => seqdata
    seq :: Dict{String, Tseq} =
        Dict{String, Tseq}()
    # per-file-feature => text
    GF  :: Dict{String, String} =
        Dict{String, String}()
    # seqname => per-seq-feature => text
    GS  :: Dict{String, Dict{String, String}} =
        Dict{String, Dict{String, String}}()
    # per-file-feature => seqdata
    GC  :: Dict{String, Tseq} =
        Dict{String, Tseq}()
    # seqname => per-seq-feature => seqdata
    GR  :: Dict{String, Dict{String, Tseq}} =
        Dict{String, Dict{String, Tseq}}()

    Stockholm{Tseq}(seq, GF, GS, GC, GR) where {Tseq} =
        new{Tseq}(seq, GF, GS, GC, GR)

    # TODO: warning for this constructor, but if it's removed,
    # `Stockholm()` doesn't work
    #
    # WARNING: Method definition (::Type{BioStockholm.Stockholm{T}
    # where T})() in module BioStockholm at
    # /home/mcm/src/BioStockholm.jl/src/BioStockholm.jl:50 overwritten
    # at util.jl:504.
    # ** incremental compilation may be fatally broken for this module
    # **
    Stockholm() = Stockholm{String}()
end

function Base.show(io::IO, mime::MIME"text/plain", sto::Stockholm)
    show(io, mime, typeof(sto))
    println(" with $(length(sto.seq)) sequences")
    println(io, "seq")
    print(io, " ")
    show(io, mime, sto.seq)
    println(io, "\nGF")
    print(io, " ")
    show(io, mime, sto.GF)
    println(io, "\nGS")
    print(io, " ")
    show(io, mime, sto.GS)
    println(io, "\nGR")
    print(io, " ")
    show(io, mime, sto.GR)
    println(io, "\nGC")
    print(io, " ")
    show(io, mime, sto.GC)
end

const stockholm_machine = let
    nl          = re"\r?\n"
    ws          = re"[ \t]+"
    feature     = re"[^ \t\n]+"
    seqname     = re"[^# \t\n][^ \t\n]*"
    text        = re"[^\n]*"
    aligned_seq = re"[^ \t\n]+"

    line_header = re"# STOCKHOLM 1.0" * nl
    line_end    = re"//" * nl
    line_GF     = re"#=GF" * ws * feature * ws * text * nl
    line_GC     = re"#=GC" * ws * feature * ws * aligned_seq * nl
    line_GS     = re"#=GS" * ws * seqname * ws * feature * ws * text * nl
    line_GR     = re"#=GR" * ws * seqname * ws * feature * ws * aligned_seq * nl
    line_seq    = seqname * ws * aligned_seq * nl
    line_empty  = re"[ \t]*" * nl

    stockholm = (
        re.rep(line_empty)
        * line_header
        * re.rep(line_GF | line_GC | line_GS | line_GR | line_seq | line_empty)
        * line_end
    )

    nl.actions[:enter]          = [:countline]
    feature.actions[:enter]     = [:enter_feature]
    feature.actions[:exit]      = [:feature]
    seqname.actions[:enter]     = [:enter_seqname]
    seqname.actions[:exit]      = [:seqname]
    text.actions[:enter]        = [:enter_text]
    text.actions[:exit]         = [:text]
    aligned_seq.actions[:enter] = [:enter_aligned_seq]
    aligned_seq.actions[:exit]  = [:aligned_seq]
    line_GF.actions[:exit]      = [:line_GF]
    line_GC.actions[:exit]      = [:line_GC]
    line_GS.actions[:exit]      = [:line_GS]
    line_GR.actions[:exit]      = [:line_GR]
    line_seq.actions[:exit]     = [:line_seq]

    Automa.compile(stockholm)
end

const stockholm_actions = Dict(
    :countline => :(linenum += 1),

    :enter_feature     => :(mark = p),
    :enter_seqname     => :(mark = p),
    :enter_text        => :(mark = p),
    :enter_aligned_seq => :(mark = p),

    :feature     => :(feature = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :seqname     => :(seqname = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :text        => :(text = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),
    :aligned_seq => :(aligned_seq = mark == 0 ? "" : String(data[mark:p-1]); mark = 0),

    :line_GF => quote
        if haskey(gf_records, feature)
            gf_records[feature] *= " " * text
        else
            gf_records[feature] = text
        end
    end,
    :line_GC => :(
        gc_records[feature] = get(gc_records, feature, "") * aligned_seq
    ),
    :line_GS => quote
        if haskey(gs_records, seqname)
            if haskey(gs_records[seqname], feature)
                gs_records[seqname][feature] *= " " * text
            else
                gs_records[seqname][feature] = text
            end
        else
            gs_records[seqname] = Dict(feature => text)
        end
    end,
    :line_GR => quote
        if haskey(gr_records, seqname)
            gr_records[seqname][feature] = get(gr_records[seqname], feature, "") * aligned_seq
        else
            gr_records[seqname] = Dict(feature => aligned_seq)
        end
    end,
    :line_seq => :(
        sequences[seqname] = get(sequences, seqname, "") * aligned_seq
    ),
)

Base.parse(::Type{Stockholm}, data::Union{String,Vector{UInt8}}) =
    parse_stockholm(data)

const context = Automa.CodeGenContext(generator=:goto, checkbounds=false)
@eval function parse_stockholm(data::Union{String,Vector{UInt8}})
    # variables for the action code
    sequences  = Dict{String,String}()               # seqname => aligned_seq
    gf_records = Dict{String,String}()               # feature => text
    gc_records = Dict{String,String}()               # feature => aligned_seq
    gs_records = Dict{String,Dict{String,String}}()  # seqname => feature => text
    gr_records = Dict{String,Dict{String,String}}()  # seqname => feature => aligned_seq
    linenum = 1
    mark = 0
    seqname = ""
    feature = ""
    text = ""
    aligned_seq = ""

    # init vars for state machine
    $(Automa.generate_init_code(context, stockholm_machine))
    p_end = p_eof = lastindex(data)

    # main loop over input data
    $(Automa.generate_exec_code(context, stockholm_machine, stockholm_actions))

    if cs != 0
        error("failed to parse on line ", linenum)
    end

    return Stockholm{String}(; seq=sequences, GF=gf_records, GC=gc_records,
                                GS=gs_records, GR=gr_records)
end

Base.print(sto::Stockholm) = print(stdout, sto)
function Base.print(io::IO, sto::Stockholm)
    # TODO: split long lines

    println(io, "# STOCKHOLM 1.0")
    # gf: feature => text
    max_len = maximum(length(f) for (f,_) in sto.GF)
    for (feature, text) in sto.GF
        indent = repeat(" ", max_len - length(feature))
        println(io, "#=GF $feature    $(indent)$(text)")
    end
    # gs: seqname => feature => text
    max_len = maximum(length(sn) + length(f) for (sn,f2t) in sto.GS for (f,_) in f2t; init=0)
    for (seqname, feature_to_text) in sto.GS
        for (feature, text) in feature_to_text
            indent = repeat(" ", max_len - (length(seqname) + length(feature)))
            println(io, "#=GS $seqname $feature    $(indent)$(text)")
        end
    end
    max_len = max(
        maximum(length(sn) for (sn,_) in sto.seq; init=0),
        # +1 for extra space char
        maximum(length(sn) + length(f) + 1 for (sn,f2t) in sto.GR for (f,_) in f2t; init=0),
        maximum(length(f) for (f,_) in sto.GC; init=0)
    )
    # seq: seqname => seqdata
    for (seqname, s) in sto.seq
        # + 5 for missing "#=GX "
        indent = repeat(" ", max_len - length(seqname) + 5)
        println(io, "$seqname    $(indent)$(s)")
        # gr: seqname => feature => seqdata
        if haskey(sto.GR, seqname)
            for (feature, r) in sto.GR[seqname]
                # +1 for extra space char
                indent = repeat(" ", max_len - (length(seqname) + length(feature) + 1))
                println(io, "#=GR $seqname $feature    $(indent)$(r)")
            end
        end
    end
    # gc: feature => seqdata
    for (feature, c) in sto.GC
        indent = repeat(" ", max_len - length(feature))
        println(io, "#=GC $feature    $(indent)$(c)")
    end
    println(io, "//")
end

end # module BioStockholm
