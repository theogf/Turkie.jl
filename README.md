# Turing + Makie -> Turkie!

WIP for an inference visualization package.

### To plot during sampling :
- [ ] Trace of the chains
- [ ] Statistics (mean and var)
- [ ] Marginals (KDE/Histograms)
- [ ] Autocorrelation plots

### Additional features :
- [ ] Selecting which variables are plotted
- [ ] Selecting what plots to show
- [ ] Giving a recording option
- [ ] Additional fine tuning features like
    - [ ] Thinning
    - [ ] Creating a buffer to limit the viewing

### Extra Features 
- [ ] Using a color mapping given some statistics
- [ ] Allow to apply transformation before plotting

## Usage:

Create a `TurkParams` object:
```julia
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
ps = TurkParams(m; nbins = 50) # default behavior : will plot the marginals and trace of all variables
cb, scene = make_callback(ps) # Create a callback function to be given to sample
chain = sample(m, NUTS(0.65), n_iters; callback = cb)
```