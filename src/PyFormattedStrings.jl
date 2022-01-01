@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end module PyFormattedStrings

export @f_str

using IterTools: groupby
import Printf


abstract type State end
struct Plain <: State end
struct SeenLbrace <: State end
struct SeenRbrace <: State end
struct InBracesBeforeContent <: State end
struct InBracesAfterContent <: State
    content::String
end

abstract type Token end

struct PlainToken <: Token
    content::String
end

struct InBracesToken <: Token
    content::Any
    format::String
end

function transition(::Plain, str::String, i::Int)
    ch = str[i]
    ch == '{' && return SeenLbrace(), nothing, nextind(str, i)
    ch == '}' && return SeenRbrace(), nothing, nextind(str, i)
    return Plain(), PlainToken(string(ch)), nextind(str, i)
end

function transition(::SeenLbrace, str::String, i::Int)
    ch = str[i]
    ch == '{' && return Plain(), PlainToken("{"), nextind(str, i)
    return InBracesBeforeContent(), nothing, i  # current character is part of content, don't move to next
end

function transition(::InBracesBeforeContent, str::String, i::Int)
    j = lastindex(str)
    while j > i
        is_valid_expr(str[i:j]) && break
        j = prevind(str, j)
    end
    @debug "" str[i:j]
    if get(str, nextind(str, j), nothing) == '}'
        # try till last colon, in case of a valid expression in brackets like "{a:f}"
        colon_ix = findprev(':', str, j)
        if !isnothing(colon_ix) && colon_ix > i
            j_new = prevind(str, colon_ix)
            if is_valid_expr(str[i:j_new])
                j = j_new
            end
        end
    end
    @debug "" str[i:j]
    return InBracesAfterContent(str[i:j]), nothing, nextind(str, j)
end

function transition(tok::InBracesAfterContent, str::String, i::Int)
    closing_ix = findnext('}', str, i)
    isnothing(closing_ix) && error("No closing '{' found")
    colon_ix = findnext(':', str, i)
    if isnothing(colon_ix) || colon_ix > closing_ix
        format_str = str[i:prevind(str, closing_ix)]
        return Plain(), InBracesToken(Meta.parse(tok.content), format_str), nextind(str, closing_ix)
    else
        @assert isempty(strip(str[i:prevind(str, colon_ix)]))
        format_str = str[nextind(str, colon_ix):prevind(str, closing_ix)]
        return Plain(), InBracesToken(Meta.parse(tok.content), format_str), nextind(str, closing_ix)
    end
end

function transition(::SeenRbrace, str::String, i::Int)
    ch = str[i]
    ch == '}' && return Plain(), PlainToken("}"), nextind(str, i)
    error("Unexpected } in f-string")
end

is_valid_expr(s::AbstractString) = try
    expr = Meta.parse(s, raise=true)
    !(expr isa Expr && expr.head == :incomplete)
catch ex
    false
end

is_empty(t::PlainToken) = t.content == ""
is_empty(::InBracesToken) = false


token_to_argument_and_formatstr(tok::PlainToken) = nothing, replace(unescape_string(tok.content), "%" => "%%")

function token_to_argument_and_formatstr(tok::InBracesToken)
    fmt = tok.format
    if isempty(strip(fmt))
        fmt = "s"
    end
    fmt = replace(fmt, '>' => "")  # printf aligns right by default
    fmt = replace(fmt, '<' => "-")  # left alignment is "<" in python and "-" in printf
    return tok.content, "%$fmt"
end

join_tokens(toks::Vector{PlainToken}) = [PlainToken(join([t.content for t in toks], ""))]
join_tokens(toks::Vector{InBracesToken}) = toks
join_tokens(toks::Vector) = join_tokens([t for t in toks])

function split_into_raw_tokens(str)
    ch = rand(Char)
    while ch ∈ str
        ch = rand(Char)
    end
    replacements_fwd = ['#' => ch]
    replacements_bck = last.(replacements_fwd) .=> first.(replacements_fwd)
    str = replace(str, replacements_fwd...)
    raw_tokens = untokenize.(tokenize(str))
    return replace.(raw_tokens, replacements_bck...)
end

function parse_to_tokens(str)
    state = Plain()
    tokens = Token[]
    i = firstindex(str)
    while i <= lastindex(str)
        @debug "" state str[i]
        state, tok, i = transition(state, str, i)
        @debug "" tok
        tok !== nothing && push!(tokens, tok)
    end
    @debug "" tokens
    state != Plain() && error("Unterminated f-string: state $state")
    tokens = filter(!is_empty, tokens)
    tokens = [tok
        for gr in groupby(typeof, tokens)
        for tok in join_tokens(gr)
    ]
    @debug "" tokens
    return tokens
end

""" F-string - formatted string literal.

Mirror Python behaviour as far as reasonably possible. Uses the `Printf` standard library under the hood.
"""
macro f_str(str)
    @debug "Starting f-string processing" str
    combined = map(token_to_argument_and_formatstr, parse_to_tokens(str))
    @debug "" combined
    format_str = join(f for (x, f) in combined)
    arguments = [x for (x, f) in combined if x !== nothing]
    @debug "" format_str arguments
    if isempty(format_str)
        return :("")
    end
    format = Printf.Format(format_str)
    expr = :(Printf.format($format, $(esc.(arguments)...)))
    @debug "" expr
    return expr
end

end
