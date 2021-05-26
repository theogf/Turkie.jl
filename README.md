[![Docs Latest](https://img.shields.io/badge/docs-dev-blue.svg)](https://theogf.github.io/Turkie.jl/dev)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://theogf.github.io/Turkie.jl/stable)
[![Coverage Status](https://coveralls.io/repos/github/theogf/Turkie.jl/badge.svg?branch=master)](https://coveralls.io/github/theogf/Turkie.jl?branch=master)
![BuildStatus](https://github.com/theogf/Turkie.jl/workflows/CI/badge.svg)

# Turing + Makie -> Turkie!

<p align="center">
  <img width="340" height="276" src="docs/src/assets/Turkie-logo.png">
</p>


<p align="center">
  <img src="docs/src/assets/Turkie-demo.gif">
</p>
WIP for an inference visualization package.

### To plot during sampling :
- [x] Trace of the chains
- [x] Statistics (mean and var)
- [x] Marginals (KDE/Histograms)
- [x] Autocorrelation plots
- [ ] Show multiple chains

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
using GLMakie # You could also use CairoMakie or another backend
@model function demo(x) # Some random Turing model
    m0 ~ Normal(0, 2)
    s ~ InverseGamma(2, 3)
    m ~ Normal(m0, √s)
    for i in eachindex(x)
        x[i] ~ Normal(m, √s)
    end
end

xs = randn(100) .+ 1 # Create some random data
m = demo(xs) # Create the model
cb = TurkieCallback(m) # Create a callback function to be given to the sample
chain = sample(m, NUTS(0.65), 300; callback = cb) # Sample and plot at the same time
```

If you want to show only some variables you can give a `Dict` to `TurkieCallback` :

```julia
cb = TurkieCallback(
            (m0 = [:trace, :mean], s = [:autocov, :var])
          )

```

You can also directly pass `OnlineStats` object : 
```julia
using OnlineStats
cb = TurkieCallback(
            (v = [Mean(), AutoCov(20)],)
          )
```

If you want to record the video do

```julia
using Makie
record(cb.figure, joinpath(@__DIR__, "video.webm")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 300; callback = cb)
end
```
