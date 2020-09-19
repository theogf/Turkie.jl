using Turing
using Turkie

@model function demo(x)
    s ~ InverseGamma(2, 3)
    m ~ Normal(0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1;
m = demo(xs);

keys(Turing.VarInfo(m).metadata)
viz_paramz = turviz(m)

chain, scene = sample_and_viz(viz_paramz, m,  NUTS(0.65), 500,);