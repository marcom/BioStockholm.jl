module BioStockholm

import Automa
import Automa.RegExp: @re_str
const re = Automa.RegExp

# TODO
# - collect data as Vector{Char} or Vector{UInt8} instead of as String?
#   - avoids excessive string concatenation

# Notes on Automa
# - automatic vars (from Automa.generate_init_code())
#   - p: index into data currently being read
#   - cs: current state of state machine (FSM), 0 is accept, 1 is start
#   - p_end
#   - p_eof

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

    return sequences, gf_records, gc_records, gs_records, gr_records
end

end # module BioStockholm
