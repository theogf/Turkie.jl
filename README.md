# Turing + Makie -> Turkie!

WIP for an inference visualization package.

### To plot during sampling :
- [x] Trace of the chains
- [x] Statistics (mean and var)
- [x] Marginals (KDE/Histograms)
- [x] Autocorrelation plots

### Additional features :
- [x] Selecting which variables are plotted
- [x] Selecting what plots to show
- [x] Giving a recording option
- [ ] Additional fine tuning features like
    - [ ] Thinning
    - [x] Creating a buffer to limit the viewing

### Extra Features 
- [ ] Using a color mapping given some statistics
- [ ] Allow to apply transformation before plotting

## Usage:
Small example:
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
ps = TurkieParams(m; nbins = 50, window = 200) # default behavior : will plot the marginals and trace of all variables
cb = TurkieCallback(ps) # Create a callback function to be given to sample
chain = sample(m, NUTS(0.65), 300; callback = cb)
```

If you want to show only some variables you can give a `Dict` to `TurkieParams` :

```julia
ps = TurkieParams(Dict(:v => [:trace, :mean],
                        :s => [:autocov, :var]))

```

If you want to record the video do

```julia
record(cb.scene, joinpath(@__DIR__, "video.webm")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 300; callback = cb)
end
```