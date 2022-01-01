module FormatInterp

export @f_str

using Tokenize: tokenize, untokenize
using Formatting
using IterTools: groupby


# https://github.com/JuliaIO/Formatting.jl/pull/100
Formatting._srepr(x::Symbol) = string(x)

# https://github.com/JuliaIO/Formatting.jl/pull/101
function Formatting._pfmt_f(out::IO, fs::FormatSpec, x::AbstractFloat)
    # separate sign, integer, and decimal part
    rax = round(abs(x), digits = fs.prec)
    sch = Formatting._signchar(x, fs.sign)
    intv = trunc(Integer, rax)
    decv = rax - intv

    # calculate length
    xlen = Formatting._ndigits(intv, Formatting._Dec()) + (fs.prec > 0 ? 1 + fs.prec : 0)
    if sch != '\0'
        xlen += 1
    end

    # print
    wid = fs.width
    if wid <= xlen
        Formatting._pfmt_float(out, sch, 0, intv, decv, fs.prec)
    elseif fs.zpad
        Formatting._pfmt_float(out, sch, wid-xlen, intv, decv, fs.prec)
    else
        a = fs.align
        if a == '<'
            Formatting._pfmt_float(out, sch, 0, intv, decv, fs.prec)
            Formatting._repprint(out, fs.fill, wid-xlen)
        else
            Formatting._repprint(out, fs.fill, wid-xlen)
            Formatting._pfmt_float(out, sch, 0, intv, decv, fs.prec)
        end
    end
end

# https://github.com/JuliaIO/Formatting.jl/pull/101
function Formatting._pfmt_float(out::IO, sch::Char, zs::Integer, intv::Real, decv::Real, prec::Int)
    # print sign
    if sch != '\0'
        print(out, sch)
    end
    # print padding zeros
    if zs > 0
        Formatting._repprint(out, '0', zs)
    end
    idecv = round(Integer, decv * exp10(prec))
    # print integer part
    if intv == 0
        print(out, '0')
    else
        Formatting._pfmt_intdigits(out, intv, Formatting._Dec())
    end
    # print decimal part
    if prec > 0
        print(out, '.')
        nd = Formatting._ndigits(idecv, Formatting._Dec())
        if nd < prec
            Formatting._repprint(out, '0', prec - nd)
        end
        Formatting._pfmt_intdigits(out, idecv, Formatting._Dec())
    end
end

abstract type State end
struct Plain <: State end
struct SeenLbrace <: State end
struct SeenRbrace <: State end
struct InBraces <: State
    nest_level::Int
    content::String
end

abstract type Token end
struct PlainToken <: Token
    content::String
end
struct InBracesToken <: Token
    content::String
end

function transition(::Plain, str::String)
    str == "{" && return SeenLbrace(), nothing
    str == "}" && return SeenRbrace(), nothing
    return Plain(), PlainToken(str)
end
function transition(::SeenLbrace, str::String)
    str == "{" && return Plain(), PlainToken("{")
    return InBraces(1, str), nothing
end
function transition(::SeenRbrace, str::String)
    str == "}" && return Plain(), PlainToken("}")
    throw(ErrorException("Unexpected } in f-string"))
end
function transition(state::InBraces, str::String)
    level = state.nest_level
    str == "{" && (level += 1)
    str == "}" && (level -= 1)
    level == 0 && return Plain(), InBracesToken(state.content)
    return InBraces(level, state.content * str), nothing
end

is_empty(t::PlainToken) = t.content == ""
is_empty(::InBracesToken) = false

function value_fmt(tok::InBracesToken)
    last_colon_ix = findlast(':', tok.content)

    parsed_before_colon = try
        if last_colon_ix === nothing
            nothing
        else
            p = Meta.parse(tok.content[begin:prevind(tok.content, last_colon_ix)])
            p isa Expr && p.head == :incomplete ? nothing : p
        end
    catch e
        if isa(e, Meta.ParseError) && occursin("colon expected", e.msg)
            nothing
        else
            rethrow(e)
        end
    end
    return if parsed_before_colon === nothing
        Meta.parse(tok.content), "s"
    else
        parsed_before_colon, tok.content[nextind(tok.content, last_colon_ix):end]
    end
end

join_tokens(toks::Vector{PlainToken}) = [PlainToken(join([t.content for t in toks], ""))]
join_tokens(toks::Vector{InBracesToken}) = toks
join_tokens(toks::Vector) = join_tokens([t for t in toks])


make_expr(tok::PlainToken) = unescape_string(tok.content)

function make_expr(tok::InBracesToken)
    parsed, format_spec = value_fmt(tok)
    expr = :(fmt($format_spec, $(esc(parsed))))
    @debug "" tok expr
    return expr
end


function parse_to_tokens(str)
    raw_tokens = untokenize.(tokenize(str))
    @debug "" str raw_tokens
    state = Plain()
    tokens = Token[]
    for raw_tok in raw_tokens
        @debug "" state raw_tok
        state, tok = transition(state, raw_tok)
        @debug "" tok
        tok !== nothing && push!(tokens, tok)
    end
    @debug "" tokens
    state != Plain() && throw(ErrorException("Unterminated f-string: state $state"))
    tokens = filter(!is_empty, tokens)
    tokens = [tok
        for gr in groupby(typeof, tokens)
        for tok in join_tokens(gr)
    ]
    @debug "" tokens
    return tokens
end

macro f_str(str)
    exprs = map(make_expr, parse_to_tokens(str))
    @debug "" exprs
    expr = :(join([$(exprs...)], ""))
    @debug "" expr
    return expr
end

end
