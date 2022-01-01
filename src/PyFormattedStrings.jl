@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end module PyFormattedStrings

export @f_str

import Printf


abstract type State end
struct Plain <: State end
struct AfterBrace <: State
    brace::Char
end
struct InBracesBeforeContent <: State end
struct InBracesAfterContent <: State
    content::String
end

abstract type Token end

struct PlainToken <: Token
    content::String
end
format_spec(tok::PlainToken) = replace(unescape_string(tok.content), "%" => "%%")
printf_argument(::PlainToken) = nothing

struct InBracesToken <: Token
    content::String
    format::Union{Nothing, String}
end
format_spec(tok::InBracesToken) = let
    fmt = something(tok.format, "s")  # use %s format if not specified
    fmt = replace(fmt, '>' => "")     # printf aligns right by default
    fmt = replace(fmt, '<' => "-")    # left alignment is "<" in python and "-" in printf
    return "%" * fmt
end
printf_argument(tok::InBracesToken) = esc(Meta.parse(tok.content))


function transition(::Plain, str::String, i::Int)
    next_bracket_ix = findnext(∈(['{', '}']), str, i)
    if isnothing(next_bracket_ix)
        return Plain(), PlainToken(str[i:end]), nextind(str, lastindex(str))
    elseif str[next_bracket_ix] ∈ ['{', '}']
        return AfterBrace(str[next_bracket_ix]), PlainToken(str[i:prevind(str, next_bracket_ix)]), nextind(str, next_bracket_ix)
    end
    @assert false
end

function transition(st::AfterBrace, str::String, i::Int)
    if str[i] == st.brace
        # two braces in a row
        return Plain(), PlainToken(string(st.brace)), nextind(str, i)
    elseif st.brace == '{'
        return InBracesBeforeContent(), nothing, i  # current character is part of content, don't move to next
    else
        @assert st.brace == '}'
        error("Unexpected } in f-string")
    end
end

function transition(::InBracesBeforeContent, str::String, i::Int)
    j = lastindex(str)
    while j > i
        closing_ix = findprev(∈(['}', ':']), str, j)
        (isnothing(closing_ix) || closing_ix < i) && error("No closing '}' found")
        j = prevind(str, closing_ix)
        is_valid_expr(str[i:j]) && break
    end
    if get(str, nextind(str, j), nothing) == '}'
        # try till last colon, in case of a valid expression in brackets like "{a:f}"
        colon_ix = findprev(':', str, j)
        if !isnothing(colon_ix) && colon_ix > i
            j_new = prevind(str, colon_ix)
            if is_valid_expr(str[i:j_new])
                @debug "" expr_valid_till_closing=str[i:j] expr_valid_till_colon=str[i:j_new]
                j = j_new
            end
        end
    end
    @debug "" valid_expr=str[i:j]
    return InBracesAfterContent(str[i:j]), nothing, nextind(str, j)
end

function transition(st::InBracesAfterContent, str::String, i::Int)
    closing_ix = findnext('}', str, i)
    isnothing(closing_ix) && error("No closing '}' found")
    colon_ix = findnext(':', str, i)
    if isnothing(colon_ix) || colon_ix > closing_ix
        # no colon within {}
        @assert i == closing_ix
        return Plain(), InBracesToken(st.content, nothing), nextind(str, closing_ix)
    else
        # there is a colon
        @assert i == colon_ix
        format_str = str[nextind(str, colon_ix):prevind(str, closing_ix)]
        return Plain(), InBracesToken(st.content, format_str), nextind(str, closing_ix)
    end
end

is_valid_expr(s::AbstractString) = try
    expr = Meta.parse(s)
    !(expr isa Expr && expr.head == :incomplete)
catch ex
    false
end

function token_to_argument_and_formatstr(tok::InBracesToken)
    fmt = something(tok.format, "s")  # use %s format if not specified
    fmt = replace(fmt, '>' => "")     # printf aligns right by default
    fmt = replace(fmt, '<' => "-")    # left alignment is "<" in python and "-" in printf
    return esc(Meta.parse(tok.content)), "%$fmt"
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
    @debug "" tokens state
    state != Plain() && error("Unterminated f-string: state $state")
    return tokens
end

""" F-string - formatted string literal.

Mirror Python behaviour as far as reasonably possible. Uses the `Printf` standard library under the hood.
"""
macro f_str(str)
    @debug "Starting f-string processing" str
    tokens = parse_to_tokens(str)
    format_str = join(map(format_spec, tokens))
    arguments = filter(!isnothing, map(printf_argument, tokens))
    @debug "" format_str arguments
    if isempty(format_str)
        # Printf doesn't support empty string
        return :("")
    end
    format = Printf.Format(format_str)
    expr = :(Printf.format($format, $(arguments...)))
    @debug "" expr
    return expr
end

end
