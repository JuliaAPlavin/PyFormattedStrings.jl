using PyFormattedStrings
using Test

import CompatHelperLocal as CHL
CHL.@check()

# using Logging
# ConsoleLogger(stdout, Logging.Debug) |> global_logger

using Documenter
doctest(PyFormattedStrings; manual=false)


@testset begin
    @testset "variable interpolation" begin
        a = 5
        б = 1.23456789
        @test f"" == ""
        @test f"abc {a} def" == "abc 5 def"
        @test f"{a}{б}" == "51.23456789"
        @test f"{Vector{Any}()}" == "Any[]"
        @test f"{'{'}" == "{"
        @test f"""{"{a}"}""" == "{a}"
        @test f"""{f"{a}"}""" == "5"
        @test f"абв {б}" == "абв 1.23456789"
        @test f"абв\n {б}" == "абв\n 1.23456789"
        @test f"abc {a:05d} def" == "abc 00005 def"
        @test f"abc {a:5d} def" == "abc     5 def"
        @test f"абв {б:6.3f}" == "абв  1.235"
        @test f"{б:.0f}" == "1"
        @test f"а{{бв{{{{{{ }}{{{б:6.3f}" == "а{бв{{{ }{ 1.235"
        @test f"""{""}""" == ""
        @test f"""{"{}"}""" == "{}"
        @test f" {a * б:.2f} а{{бв{{{'{'}{{{{ }}{{{б:6.3f}" == " 6.17 а{бв{{{{ }{ 1.235"
        @test f"{ifelse(true, 1, 2)}" == "1"
        @test f"{true ? 1 : 2}" == "1"
        @test f"{true ? 1 : 2 :.2f}" == "1.00"
        @test f"{(:abc)}" == "abc"
        @test f"{(:abc):5s}" == "  abc"
        @test f"{(:abc):-5s}" == "abc  "
        @test f"{a > 4 ? :abc : :def}" == "abc"
        @test f"{:a == :a ? :abc : :def}" == "abc"
        @test f"{NTuple{1,Int64}}{{{Val{Int64}}" == "Tuple{Int64}{Val{Int64}"
        @test f"{{Vector{Int64}}}" == "{VectorInt64}"
        @test f"{{Vector{Int64:7s}}}" == "{Vector  Int64}"
        @test f"{{Vector{Int64:-7s}}}" == "{VectorInt64  }"
        @test f"{push!(Vector{Symbol}(), a > 4 ? :abc : :def)}" == "[:abc]"
        @test f"{:abc == :abc ? push!(Vector{Symbol}(), a > 4 ? :abc : :def) : nothing}" == "[:abc]"
        @test f"%123" == "%123"
        @test f"{5}%" == "5%"
        @test f"{a}%" == "5%"
        @test f"{б:.2f}%" == "1.23%"
        @test f"%{a % 2:d}%%%" == "%1%%%"
        @test_broken @eval(f"{a:#d}")  # for some reason "#d}" gets treated as a single token
        @test f"{a:<3d}" == "5  "
        @test f"{a:>3d}" == "  5"
    end

    @testset "errors" begin
        # workaround for all macro exceptions being wrapped in LoadError in Julia
        @test_throws ErrorException try @eval(f"{") catch err; throw(err.error) end
        @test_throws ErrorException try @eval(f"{'") catch err; throw(err.error) end
        @test_throws ErrorException try @eval(f""" {" """) catch err; throw(err.error) end
        @test_throws ErrorException try @eval(f"""{"}""") catch err; throw(err.error) end
        @test_throws ErrorException try @eval(f"{(}") catch err; throw(err.error) end
        @test_throws Exception try @eval(f"{(]}") catch err; throw(err.error) end
    end

    @testset "optimality" begin
        # test that no unnecessary tokens/splits are given
        @test length(PyFormattedStrings.parse_to_tokens("")) == 0
        @test length(PyFormattedStrings.parse_to_tokens("abc d e f")) == 1
        @test length(PyFormattedStrings.parse_to_tokens("abc d {var} e f")) == 3
    end
end
