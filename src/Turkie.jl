module Turkie

using AbstractPlotting: Scene, Point2f0
using AbstractPlotting: barplot!, lines!, scatter! # Plotting tools
using AbstractPlotting: Observable, Node, lift, on # Observable tools
using AbstractPlotting: recordframe! # Recording tools
using AbstractPlotting.MakieLayout # Layouting tool
using Colors, ColorSchemes # Colors tools
using KernelDensity # To be able to give a KDE
using OnlineStats # Estimators
using DynamicPPL: VarInfo, Model

export TurkieCallback

export addIO!, record

include("online_stats_plots.jl")

const std_colors = ColorSchemes.seaborn_colorblind

name(s::Symbol) = name(Val(s))
name(::Val{T}) where {T} = string(T)
name(s::OnlineStat) = string(nameof(typeof(s)))

"""
    TurkieCallback(model::DynamicPPL.Model, plots::Series/AbstractVector; window=1000, kwargs...)

## Keyword arguments
- `window=1000` : Use a window for plotting the trace
"""
TurkieCallback

struct TurkieCallback
    scene::Scene
    data::Dict{Symbol, MovingWindow}
    axis_dict::Dict
    vars::Dict{Symbol, Any}
    params::Dict{Any, Any}
    iter::Observable{Int}
end

function TurkieCallback(model::Model, plots::Series; kwargs...)
    return TurkieCallback(model, collect(s.stats); kwargs...)
end

function TurkieCallback(model::Model, plots::AbstractVector = [:histkde, Mean(Float32), Variance(Float32), AutoCov(20, Float32)]; kwargs...)
    variables = VarInfo(model).metadata
    return TurkieCallback(
        Dict(Pair.(keys(variables), Ref(plots)));
        kwargs...
        )
end

function TurkieCallback(varsdict::Dict; kwargs...)
    return TurkieCallback(varsdict, Dict{Symbol,Any}(kwargs...))
end

function TurkieCallback(vars::Dict, params::Dict)
# Create a scene and a layout
    outer_padding = 5
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    window = get!(params, :window, 1000)
    iter = Node(0)
    data = Dict{Symbol, MovingWindow}(:iter => MovingWindow(window, Int))
    obs = Dict{Symbol, Any}()
    axis_dict = Dict()
    for (i, (variable, plots)) in enumerate(vars)
        data[variable] = MovingWindow(window, Float32)
        axis_dict[(variable, :varname)] = layout[i, 1, Left()] = Label(scene, string(variable), textsize = 30)
        axis_dict[(variable, :varname)].padding = (0, 50, 0, 0)
        onlineplot!(scene, layout, axis_dict, plots, iter, data, variable, i)
    end
    on(iter) do i
        if i > 1 # To deal with autolimits a certain number of samples are needed
            for (variable, plots) in vars
                for p in plots
                    autolimits!(axis_dict[(variable, p)])
                end
            end
        end
    end
    MakieLayout.trim!(layout)
    TurkieCallback(scene, data, axis_dict, vars, params, iter)
end

function addIO!(cb::TurkieCallback, io)
    cb.params[:io] = io
end

function (cb::TurkieCallback)(rng, model, sampler, transition, iteration)
    fit!(cb.data[:iter], iteration)
    for (vals, ks) in values(transition.θ)
        for (k, val) in zip(ks, vals)
            if haskey(cb.data, Symbol(k))
                fit!(cb.data[Symbol(k)], Float32(val))
            end
        end
    end
    cb.iter[] += 1
    if haskey(cb.params, :io)
        recordframe!(cb.params[:io])
    end
end

end
