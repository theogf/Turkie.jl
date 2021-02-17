# Turing + Makie -> Turkie!

<p align="center">
  <img width="340" height="276" src="Turkie-logo.png">
</p>

WIP for an inference visualization package.

This package is not registered at the moment and will probably be merged with [TuringCallbacks](https://github.com/torfjelde/TuringCallbacks.jl) at some point.
To try it nonetheless run :
```
] add https://github.com/theogf/Turkie.jl
```

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
using Makie # You could also use CairoMakie or another backend
@model function demo(x) # Some random Turing model
    v ~ InverseGamma(3, 2)
    s ~ InverseGamma(2, 3)
    m ~ Normal(0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1;
m = demo(xs);
cb = TurkieCallback(m) # Create a callback function to be given to sample
chain = sample(m, NUTS(0.65), 300; callback = cb)
```

If you want to show only some variables you can give a `Dict` to `TurkieCallback` :

```julia
cb = TurkieCallback(Dict(:v => [:trace, :mean],
                        :s => [:autocov, :var]))

```

You can also directly pass `OnlineStats` object : 
```julia
using OnlineStats
cb = TurkieCallback(Dict(:v => [Mean(), AutoCov(20)]))
```

If you want to record the video do

```julia
using Makie
record(cb.scene, joinpath(@__DIR__, "video.webm")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 300; callback = cb)
end
```
