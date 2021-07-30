module Turkie

using Makie: Figure, Scene, Point2f0
using Makie: barplot!, lines!, scatter! # Plotting tools
using Makie: Observable, Node, lift, on # Observable tools
using Makie: recordframe! # Recording tools
using Makie.MakieLayout # Layouting tool
using Colors, ColorSchemes # Colors tools
using KernelDensity # To be able to give a KDE
using OnlineStats # Estimators
using Turing: DynamicPPL.VarInfo, DynamicPPL.Model, Inference._params_to_array

export TurkieCallback

export addIO!, record

include("online_stats_plots.jl")
include("utils.jl")
 # Uses the colorblind scheme of seaborn by default
const std_colors = ColorSchemes.seaborn_colorblind

"""
    TurkieCallback(args...; kwargs....)
    
## Arguments
- Option 1 : 
    `model::DynamicPPL.Model, plots::Series/AbstractVector=[:histkde, Mean(Float32), Variance(Float32), AutoCov(20, Float32)]`

For each of the variables of the given model each `plot` from `plots` will be plotted
Multidimensional variable will be automatically have indices added to them
- Option 2 :
    `vars::NamedTuple/Dict`
Will plot each pair of symbol and series of plots.
Note that for multidimensional variable you should pass a Symbol as `Symbol("m[1]")` for example.
See the docs for some examples.
## Keyword arguments
- `window=1000` : Use a window for plotting the trace
- `refresh=false` : Restart the plots from scratch everytime `sample` is called again (still WIP)
"""
TurkieCallback

struct TurkieCallback{TN<:NamedTuple,TS<:AbstractDict,TD<:AbstractDict}
    figure::Figure
    data::Dict{Symbol, MovingWindow}
    axis_dict::Dict
    vars::TN
    stats::TS
    params::TD
    iter::Observable{Int}
end

function TurkieCallback(model::Model, plots::Series; kwargs...)
    return TurkieCallback(model, collect(plots.stats); kwargs...)
end

function TurkieCallback(model::Model, plots::AbstractVector = [:histkde, Mean(Float32), Variance(Float32), AutoCov(20, Float32)]; kwargs...)
    vars, _ = _params_to_array([VarInfo(model)])
    return TurkieCallback(
        (;Pair.(vars, Ref(plots))...); # Return a named Tuple
        kwargs...
    )
end

function TurkieCallback(vars::Union{Dict, NamedTuple}; kwargs...)
    return TurkieCallback((;vars...), Dict{Symbol,Any}(kwargs...))
end

function TurkieCallback(vars::NamedTuple, params::Dict)
# Create a scene and a layout
    outer_padding = 5
    fig = Figure(;resolution = (1200, 700), figure_padding=outer_padding)
    window = get!(params, :window, 1000)
    get!(params, :refresh, false)
    params[:t0] = 0
    iter = Observable(0)
    data = Dict{Symbol, MovingWindow}(:iter => MovingWindow(window, Int))
    axis_dict = Dict()
    stats_dict = Dict()
    for (i, variable) in enumerate(keys(vars))
        plots = vars[variable]
        data[variable] = MovingWindow(window, Float32)
        axis_dict[(variable, :varname)] = fig[i, 1, Left()] = Label(fig, string(variable), textsize = 30)
        axis_dict[(variable, :varname)].padding = (0, 60, 0, 0)   
        onlineplot!(fig, axis_dict, stats_dict, plots, iter, data, variable, i)
    end
    on(iter) do i
        if i > 1 # To deal with autolimits a certain number of samples are needed
            for variable in keys(vars)
                for p in vars[variable]
                    autolimits!(axis_dict[(variable, p)])
                end
            end
        end
    end
    MakieLayout.trim!(fig.layout)
    display(fig)
    return TurkieCallback(fig, data, axis_dict, vars, stats_dict, params, iter)
end

function addIO!(cb::TurkieCallback, io)
    cb.params[:io] = io
end

function (cb::TurkieCallback)(rng, model, sampler, transition, state, iteration; kwargs...)
    if iteration == 1
        if cb.params[:refresh]
            refresh_plots!(cb)
        end
        cb.params[:t0] = cb.iter[] 
    end
    fit!(cb.data[:iter], iteration + cb.params[:t0]) # Update the iteration value
    for (variable, val) in zip(_params_to_array([transition])...)
        if haskey(cb.data, variable) # Check if symbol should be plotted
            fit!(cb.data[variable], Float32(val)) # Update its value
        end
    end
    cb.iter[] = cb.iter[] + 1
    if haskey(cb.params, :io)
        recordframe!(cb.params[:io])
    end
end

function refresh_plots!(cb::TurkieCallback)
    cb.iter[] = 0
    for v in keys(cb.data)
        cb.data[v] = MovingWindow(cb.params[:window], Float32)
        for stat in cb.vars[v]
            reset!(cb.stats[(v, stat)], stat)
        end
    end
end

end
