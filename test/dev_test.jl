using Turing
using Turkie
using OnlineStats
using GLMakie
@model function demo(x)
    v ~ InverseGamma(3, 2)
    s ~ InverseGamma(2, v)
    m ~ Normal(0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1;
m = demo(xs);

cb = TurkieCallback(m);
# chain = sample(m,  HMC(0.5, 10), 40; callback = cb);
chain = sample(m,  NUTS(0.65), 500; callback = cb);

# using Makie
# record(cb.scene, joinpath(@__DIR__, "video.gif")) do io
#     addIO!(cb, io)
#     sample(m,  NUTS(0.65), 300; callback = cb)
# end