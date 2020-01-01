module FormatInterp
export @f_str
using Tokenize
using Formatting


macro f_str(str)
    @debug "" str
    @debug tokenize(str) |> collect
    toks = tokenize(str) |> collect
    exprs = []
    state = Dict(:name => :plain, :num_lbraces => 0, :num_rbraces => 0)
    for (it, tok) in enumerate(toks)
        @debug "" state tok
        if Tokens.kind(tok) == Tokens.ERROR
            throw(ErrorException("Error token in f-string: $tok"))
        elseif Tokens.kind(tok) == Tokens.ENDMARKER
            @assert it == length(toks)
            break
        end
        tok_next = it < length(toks) ? toks[it + 1] : nothing
        if state[:name] == :plain
            if Tokens.kind(tok) == Tokens.LBRACE
                if state[:num_lbraces] == 1
                    push!(exprs, "{")
                    state[:num_lbraces] = 0
                    continue        
                elseif tok_next != nothing && Tokens.kind(tok_next) == Tokens.LBRACE
                    state[:num_lbraces] += 1
                    continue
                else
                    state = Dict(:name => :in_braces, :parts => [], :level => 1)
                    continue
                end
            elseif Tokens.kind(tok) == Tokens.RBRACE
                if state[:num_rbraces] == 1
                    push!(exprs, "}")
                    state[:num_rbraces] = 0
                    continue        
                elseif tok_next != nothing && Tokens.kind(tok_next) == Tokens.RBRACE
                    state[:num_rbraces] += 1
                    continue
                else
                    throw(ErrorException("Unexpected } in f-string"))
                end
            end
            push!(exprs, Tokens.untokenize(tok))
        elseif state[:name] == :in_braces
            if Tokens.kind(tok) == Tokens.LBRACE
                state[:level] += 1
            elseif Tokens.kind(tok) == Tokens.RBRACE
                state[:level] -= 1
                if state[:level] == 0
                    expr = Meta.parse(join(state[:parts], ""))
                    push!(exprs, :(string($(esc(expr)))))
                    state = Dict(:name => :plain, :num_lbraces => 0, :num_rbraces => 0)
                    continue
                end
            elseif state[:level] == 1 && Tokens.kind(tok) == Tokens.OP && Tokens.untokenize(tok) == ":"
                expr = Meta.parse(join(state[:parts], ""))
                state = Dict(:name => :format_spec, :value_expr => expr, :parts => [])
                continue
            end
            push!(state[:parts], Tokens.untokenize(tok))
        elseif state[:name] == :format_spec
            if Tokens.kind(tok) == Tokens.RBRACE
                format_spec = join(state[:parts], "")
                expr = :(fmt( $(esc(format_spec)), $(esc(state[:value_expr])) ))
                push!(exprs, expr)
                state = Dict(:name => :plain, :num_lbraces => 0, :num_rbraces => 0)
                continue
            end
            push!(state[:parts], Tokens.untokenize(tok))
        else
            throw(ErrorException("Unsupported state: $state"))
        end
    end
    @debug "" state
    if state != Dict(:name => :plain, :num_lbraces => 0, :num_rbraces => 0)
        throw(ErrorException("Unterminated f-string: state $state"))
    end
    @debug "" exprs
    expr = :(join([$(exprs...)], ""))
    @debug "" expr
    return expr
end

end # module
