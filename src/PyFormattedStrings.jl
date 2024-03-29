module PyFormattedStrings

export @f_str, @ff_str

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
printf_arguments(::PlainToken) = []

struct InBracesToken <: Token
    content::String
    format::Union{Nothing, String}
end
format_spec(tok::InBracesToken) = let
    fmt = something(tok.format, "s")  # use %s format if not specified
    fmt = replace(fmt, '>' => "")          # printf aligns right by default
    fmt = replace(fmt, '<' => "-")         # left alignment is "<" in python and "-" in printf,
    fmt = replace(fmt, r"{[^}]*}" => "*")  # dynamic width and precision
    return "%$fmt"
end
function printf_arguments(tok::InBracesToken)
    content_arg = Meta.parse(tok.content)
    isnothing(tok.format) && return [content_arg]
    m = eachmatch(r"{([^}]*)}", tok.format)
    isempty(m) && return [content_arg]
    return [
        [Meta.parse(m[1]) for m in m];
        [content_arg];
    ]
end


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

function findclosing(closing::Char, str::String, i::Int)
    @assert closing == '}'
    opening = '{'
    depth = 1
    while true
        nextix = findnext(∈((opening, closing)), str, i)
        if isnothing(nextix)
            return nothing
        elseif str[nextix] == opening
            depth += 1
        elseif str[nextix] == closing
            depth -= 1
        else
            @assert false
        end
        if depth == 0
            return nextix
        end
        i = nextind(str, nextix)
    end
end

function transition(st::InBracesAfterContent, str::String, i::Int)
    closing_ix = findclosing('}', str, i)
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
    return Meta.parse(tok.content), "%$fmt"
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

"""    f"python-like formatting string"

The so-called "f-string", or formatted string literal.

Mirrors Python behaviour as far as reasonably possible. Uses the `Printf` standard library under the hood.
"""
macro f_str(str)
    @debug "Starting f-string processing" str
    tokens = parse_to_tokens(str)
    format_str = join(map(format_spec, tokens))
    arguments = mapreduce(printf_arguments, vcat, tokens; init=[])
    @debug "" format_str arguments
    if isempty(format_str)
        # Printf doesn't support empty string
        return :("")
    end
    format = Printf.Format(format_str)
    expr = :($(Printf.format)($format, $(arguments...)))
    @debug "" expr
    return expr |> esc
end

macro ff_str(str)
    tokens = parse_to_tokens(str)
    format_str = join(map(format_spec, tokens))
    arguments = mapreduce(printf_arguments, vcat, tokens; init=[])
    @debug "" format_str arguments
    if isempty(format_str)
        # Printf doesn't support empty string
        return :((a...; k...) -> "")
    end
    format = Printf.Format(format_str)
    argsym = gensym(:arg)
    arguments = postwalk(arguments) do x
        if x isa Symbol
            xq = QuoteNode(x)
            return :(hasproperty($argsym, $xq) ? getproperty($argsym, $xq) : $x)
        end
        return x
    end
    return :($(argsym) -> $(Printf.format)($format, $(arguments...))) |> esc
end


# from MacroTools:
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))
walk(x::Union{Tuple,AbstractArray}, inner, outer) = outer(map(inner, x))
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)


using PrecompileTools
@compile_workload @eval begin
    f"abc {123}"
end

end
