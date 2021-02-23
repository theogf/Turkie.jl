# Turkie.jl
[![Turkie.jl](/assets/Turkie-logo.png)](https://github.com/theogf/Turkie.jl)

[![Docs Latest](https://img.shields.io/badge/docs-dev-blue.svg)](https://theogf.github.io/Turkie.jl/dev)
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://theogf.github.io/Turkie.jl/stable)
![BuildStatus](https://github.com/theogf/Turkie.jl/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/theogf/Turkie.jl/badge.svg?branch=master)](https://coveralls.io/github/theogf/Turkie.jl?branch=master)


A [Julia](http://julialang.org) package for vizualizing dynamically sampling and statistics of Bayesian models
***

## Installation

Turkie is a [registered package](http://pkg.julialang.org) and is symply installed by running
```julia
pkg> add Turkie
```

## Basic example with Turing

Right now `Turkie` only works with `Turing.jl` but it should be compatible with any sampling algorithm following the [`AbstractMCMC.jl`](https://github.com/TuringLang/AbstractMCMC.jl) interface

Here is a simple example to start right away :
```julia
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

xs = randn(100) .+ 1 # Create some random data
m = demo(xs) # Create the model
cb = TurkieCallback(m) # Create a callback function to be given to the sample
chain = sample(m, NUTS(0.65), 300; callback = cb) # Sample and plot at the same time
```

You should observe something like this :

![Turkie Video](/assets/Turkie-demo.webm)

## The example in details


If we look at the last 2 steps:
```julia
c = TurkieCallback(m)
```
will create a `Makie` window and store the names of all the (non-observed) variables of `m`.
By default the quantities looked at for each of the variables are :
 - A combination of an histogram and a KDE approximation
 - The sample mean
 - The sample variance
 - The auto-covariance of the samples

Next :
```julia
chain = sample(m, NUTS(0.65), 300; callback = cb) 
```
This is your typical posterior sampling with Turing.jl.
While sampling the callback object `cb` will be called and the statistics will be **updated live**.

## Tuning the quantities

Of course the default is not always desirable.
You can chose what variables and what quantities are shown by giving a `Dict` to `TurkieCallback` instead of a model.
For example,
```julia
cb = TurkieCallback(Dict(:v => [:trace, :mean],
                        :s => [:autocov, :var]))
```
will only show the trace and the sample mean of `v` and the auto-covariance and variance of `s`.
Pairs should be of the type `{Symbol,AbstractVector}`.
In these vectors you can either throw a symbol from the following list:
- `:mean` : The sample mean of the variable
- `:var` : The sample variance of the variable
- `:trace` : The trace of the variable (every value)
- `:hist` : An histogram of the variable
- `:kde` : A KDE estimation of the variable
- `:kdehist` : A KDE estimation combined with an histogram
- `:autocov` : The sample auto-covariance

You can also pass an `OnlineStat` object from [`OnlineStats.jl`](https://github.com/joshday/OnlineStats.jl).
By default, it will plot the value of the `OnlineStat` at every iteration as a trace.
If you want a specific implementation of a certain stat please [open an issue](https://github.com/theogf/Turkie.jl/issues/new).

## Recording the sampling

If you want to make a cool animation you can use the built-in recording features of Makie.
Here is the simple example, using the Turing example from above:
```julia
record(cb.scene, joinpath(@__DIR__, "video.webm")) do io
    addIO!(cb, io)
    sample(m,  NUTS(0.65), 300; callback = cb)
end
```
