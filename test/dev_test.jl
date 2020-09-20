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
ps = TurkieParams(m; nbins = 20)
cb = TurkieCallback(ps);
# chain = sample(m,  HMC(0.5, 10), 40; callback = cb);
chain = sample(m,  NUTS(0.65), 300; callback = cb);