using Turing
using Turkie
using Makie # You could also use CairoMakie or another backend
@model function demo(x) # Some random Turing model
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
chain = sample(m, NUTS(0.65), 300; callback = cb)


record(cb.scene, joinpath(@__DIR__, "video.gif")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 50; callback = cb)
end