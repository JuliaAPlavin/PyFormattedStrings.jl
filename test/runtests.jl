using FormatInterp
using Test
using Logging

# ConsoleLogger(stdout, Logging.Debug) |> global_logger

a = 5
б = 1.23456789
@test f"abc {a} def" == "abc 5 def"
@test f"{Vector{Any}()}" == "Any[]"
@test f"{'{'}" == "{"
@test f"""{"{a}"}""" == "{a}"
@test f"""{f"{a}"}""" == "5"
@test f"абв {б}" == "абв 1.23456789"
@test f"abc {a:05d} def" == "abc 00005 def"
@test f"абв {б:6.3f}" == "абв  1.235"
@test f"а{{бв{{{{{{ }}{{{б:6.3f}" == "а{бв{{{ }{ 1.235"
@test f"""{""}""" == ""
@test f"""{"{}"}""" == "{}"
@test f" {a * б:.2f} а{{бв{{{'{'}{{{{ }}{{{б:6.3f}" == " 6.17 а{бв{{{{ }{ 1.235"
@test f"{ifelse(true, 1, 2)}" == "1"
@test f"{true ? 1 : 2}" == "1"
@test f"{true ? 1 : 2 :.2f}" == "1.00"

# workaround for all macro exceptions being wrapped in LoadError in Julia
@test_throws ErrorException try @eval(f"{") catch err; throw(err.error) end
@test_throws ErrorException try @eval(f"{'") catch err; throw(err.error) end
@test_throws ErrorException try @eval(f""" {" """) catch err; throw(err.error) end
@test_throws ErrorException try @eval(f"""{"}""") catch err; throw(err.error) end
@test_throws ErrorException try @eval(f"{(}") catch err; throw(err.error) end
@test_throws Exception try @eval(f"{(]}") catch err; throw(err.error) end
