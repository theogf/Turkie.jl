using Turkie
using Test
using CairoMakie
CairoMakie.activate!()
using OnlineStats
using Turing

@testset "Turkie.jl" begin
    Turing.@model function demo(x) # Some random Turing model
        m0 ~ Normal(0, 2)
        s ~ InverseGamma(2, 3)
        m ~ Normal(m0, √s)
        for i in eachindex(x)
            x[i] ~ Normal(m, √s)
        end
    end
    N = 10
    xs = randn(N) .+ 1
    model = demo(xs)
    vars = [:m0, :s, :m]
    @testset "Interface" begin
        @test Turkie.std_colors == Turkie.ColorSchemes.seaborn_colorblind
        @test Turkie.name(:blah) == "blah"
        @test Turkie.name(OnlineStats.Mean(Float32)) == "Mean"

        cb = TurkieCallback(model; blah=2.0)
        @test cb.figure isa Figure
        @test sort(collect(keys(cb.data))) == sort(vcat(vars, :iter))
        @test cb.data[:m] isa MovingWindow{Float32}
        @test sort(collect(keys(cb.vars))) == sort(vars)
        @test cb.vars[:m][1] == :histkde
        @test cb.vars[:m][2] == Mean(Float32)
        @test cb.vars[:m][3] == Variance(Float32)
        @test cb.vars[:m][4] == AutoCov(20, Float32)
        @test length(cb.axis_dict) == 15
        @test cb.params[:blah] == 2.0
        @test cb.params[:window] == 1000
        @test cb.iter[] == 0
        @test cb.iter isa Observable{Int}
    end
    @testset "Testing all possible plots" begin
        @testset "Vector of symbols" begin
            for stat in [:histkde, :kde, :hist, :mean, :var, :trace, :autocov]
                cb = TurkieCallback(Dict(:m => [stat]))
                sample(model, MH(), 50; progress=false, callback=cb) 
            end
        end 
        @testset "Series" begin
            for stat in [Mean(Float32), Variance(Float32)]
                cb = TurkieCallback(model, OnlineStats.Series(stat))
                sample(model, MH(), 50; progress=false, callback=cb)
            end
        end
    end

end
