using Turing
using Turkie

@model function demo(x)
    v ~ InverseGamma(3, 2)
    s ~ InverseGamma(2, 3)
    m ~ Normal(0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1;
m = demo(xs);

keys(Turing.VarInfo(m).metadata)
viz_paramz = TurkParams(m; nbins = 20)
cb, scene = make_callback(viz_paramz);
chain = sample(m,  NUTS(0.65), 500; callback = cb);