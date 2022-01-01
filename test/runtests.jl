using PyFormattedStrings
using Test

# using Logging; ConsoleLogger(stdout, Logging.Debug) |> global_logger


@testset "variable interpolation" begin
    a = 5
    б = 1.23456789
    c = 1234
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
    @test f"{б:#.0f}" == "1."
    @test f"{c:x}" == "4d2"
    @test f"{c:#x}" == "0x4d2"
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
    @test f"{a:<3d}" == "5  "
    @test f"{a:>3d}" == "  5"
    @test f"{nothing}" == "nothing"
    @test f"{missing}" == "missing"
    @test f"\t\\" == "\t\\"
    @test f"""a {join(x for x in ["11", "22", "33"])} b""" == "a 112233 b"
    @test f"""a {join((f"{x:.1f}" for x in [11, 22, 33]), " ")} b""" == "a 11.0 22.0 33.0 b"
    @test f"""{"xy"}""" == "xy"
    @test f"""{raw"xy"}""" == "xy"
    @test f"""{"$a"}""" == "5"
    @test f"""{"\$a"}""" == raw"$a"
    @test f"""{raw"$a"}""" == raw"$a"
    @test f"""{raw"$a$"}""" == raw"$a$"
    @test f"""abc "{a} def""" == "abc \"5 def"
    @test f"""abc "{a}" def""" == "abc \"5\" def"
    @test f"""abc "{a }" def""" == "abc \"5\" def"
    @test f"""abc "{a :d}" def""" == "abc \"5\" def"
    @test f"""abc "{ a :d}" def""" == "abc \"5\" def"
end

@testset "errors" begin
    # workaround for all macro exceptions being wrapped in LoadError in Julia
    @test_throws ErrorException try @eval(f"{") catch err; throw(err.error) end
    @test_throws ErrorException try @eval(f"{'") catch err; throw(err.error) end
    @test_throws ErrorException try @eval(f""" {" """) catch err; throw(err.error) end
    @test_throws ErrorException try @eval(f"""{"}""") catch err; throw(err.error) end
    @test_throws ErrorException try @eval(f"{(}") catch err; throw(err.error) end
    @test_throws ErrorException try @eval(f"}1") catch err; throw(err.error) end
    @test_throws Exception try @eval(f"{(]}") catch err; throw(err.error) end
end

import CompatHelperLocal as CHL
CHL.@check()

using Documenter
doctest(PyFormattedStrings; manual=false)
