using Pkg; Pkg.activate("..")
using Turing
using Turkie
using GLMakie # You could also use CairoMakie or another backend
using CairoMakie
GLMakie.activate!()
CairoMakie.activate!()
Turing.@model function demo(x) # Some random Turing model
    m0 ~ Normal(0, 2)
    s ~ InverseGamma(2, 3)
    m ~ Normal(m0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1;
m = demo(xs);
cb = TurkieCallback(m) # Create a callback function to be given to the sample function
chain = sample(m, NUTS(0.65), 30; callback = cb)


record(cb.figure, joinpath(@__DIR__, "video.gif")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 50; callback = cb)
end

## Let's test if Soss work as well!
using Soss
using Random

sossdemo = Soss.@model x begin
    m0 ~ Normal(0, 2)
    s ~ InverseGamma(2, 3)
    m ~ Normal(m0, √s)
    x ~ For(eachindex(x)) do i
        Normal(m, √s)
    end
end

cb = TurkieCallback(Dict(:m0 => [:trace, :mean],
                        :s => [:autocov, :var]))

advancedHMC(sossdemo(), (x=xs,), 100; callback = cb)

## Test for array of parameters
using LinearAlgebra
D = 1
N = 20
Turing.@model function vectordemo(x, y, σ)
    m ~ Normal(0, 10)
    β ~ MvNormal(m * ones(D + 1), ones(D + 1))
    for i in eachindex(y)
        y[i] ~ Normal(dot(β, vcat(1, x[i])), σ)
    end
end

x = [rand(D) for _ in 1:N]
β = randn(D + 1) * 2
σ = 0.1
y = dot.(Ref(β), vcat.(1, x)) .+ σ * randn(N)

m = vectordemo(x, y, σ)

cb = TurkieCallback(m) # Create a callback function to be given to the sample function

chain = sample(m, NUTS(0.65), 200; callback = cb)
