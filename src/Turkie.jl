module Turkie

using AbstractPlotting: Scene, Point2f0
using AbstractPlotting: barplot!, lines!, scatter! # Plotting tools
using AbstractPlotting: Observable, Node, lift, on # Observable tools
using AbstractPlotting: recordframe! # Recording tools
using AbstractPlotting.MakieLayout # Layouting tool
using Colors, ColorSchemes # Colors tools
using KernelDensity # To be able to give a KDE
using OnlineStats # Estimators
using Turing: DynamicPPL.VarInfo, DynamicPPL.Model, Inference._params_to_array

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

struct TurkieCallback{TN<:NamedTuple,TD<:AbstractDict}
    scene::Scene
    data::Dict{Symbol, MovingWindow}
    axis_dict::Dict
    vars::TN
    params::TD
    iter::Observable{Int}
end

function TurkieCallback(model::Model, plots::Series; kwargs...)
    return TurkieCallback(model, collect(plots.stats); kwargs...)
end

function TurkieCallback(model::Model, plots::AbstractVector = [:histkde, Mean(Float32), Variance(Float32), AutoCov(20, Float32)]; kwargs...)
    vars, vals = _params_to_array([VarInfo(model)])
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
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    window = get!(params, :window, 1000)
    refresh = get!(params, :refresh, false)
    params[:t0] = 0
    iter = Observable(0)
    data = Dict{Symbol, MovingWindow}(:iter => MovingWindow(window, Int))
    obs = Dict{Symbol, Any}()
    axis_dict = Dict()
    for (i, variable) in enumerate(keys(vars))
        plots = vars[variable]
        data[variable] = MovingWindow(window, Float32)
        axis_dict[(variable, :varname)] = layout[i, 1, Left()] = Label(scene, string(variable), textsize = 30)
        axis_dict[(variable, :varname)].padding = (0, 60, 0, 0)   
        onlineplot!(scene, layout, axis_dict, plots, iter, data, variable, i)
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
    MakieLayout.trim!(layout)
    display(scene)
    TurkieCallback(scene, data, axis_dict, vars, params, iter)
end

function addIO!(cb::TurkieCallback, io)
    cb.params[:io] = io
end

function (cb::TurkieCallback)(rng, model, sampler, transition, iteration)
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
    cb.iter[] += 1
    if haskey(cb.params, :io)
        recordframe!(cb.params[:io])
    end
end

function refresh_plots!(cb)
    #TODO
end

end
