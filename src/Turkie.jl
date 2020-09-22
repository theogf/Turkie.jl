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

export TurkieParams, TurkieCallback

export addIO!, record

include("online_stats_plots.jl")

const std_colors = ColorSchemes.seaborn_colorblind

struct TurkieParams
    vars::Dict{Symbol, Any}
    params::Dict{Symbol, Any}
end

function TurkieParams(model::Model; kwargs...) # Only needed for DynamicPPL models
    variables = VarInfo(model).metadata
    return TurkieParams(Dict(Pair.(keys(variables), Ref([:trace])));
    # :histkde, Mean(), Variance(), AutoCov(20)])))
    kwargs...)
end

function TurkieParams(varsdict::Dict; kwargs...)
    return TurkieParams(varsdict, Dict(kwargs...))
end

struct TurkieCallback
    scene::Scene
    data::Dict{Symbol, MovingWindow}
    axes_dict::Dict
    params::TurkieParams
    iter::Observable{Int64}
end

function TurkieCallback(params::TurkieParams)
# Create a scene and a layout
    outer_padding = 5
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    display(scene)

    window = get!(params.params, :window, 1000)

    n_rows = length(keys(params.vars))
    n_cols = maximum(length.(values(params.vars))) 
    n_plots = n_rows * n_cols
    iter = Node(0)
    data = Dict{Symbol, MovingWindow}(:iter => MovingWindow(window, Int64))
    obs = Dict{Symbol, Any}()
    axes_dict = Dict()
    for (i, (variable, plots)) in enumerate(params.vars)
        data[variable] = MovingWindow(window, Float32)
        axes_dict[(variable, :varname)] = layout[i, 1, Left()] = LText(scene, string(variable), textsize = 30)
        axes_dict[(variable, :varname)].padding = (0, 50, 0, 0)
        for (j, p) in enumerate(plots)
            obs[variable] = Observable[]
            axes_dict[(variable, p)] = layout[i, j] = LAxis(scene, title = "$p")
            onlineplot!(axes_dict[(variable, p)], p, iter, data[variable], data[:iter], i, j)
            tight_ticklabel_spacing!(axes_dict[(variable, p)])
        end
    end
    lift(iter) do i
        if i > 10 # To deal with autolimits a certain number of samples are needed
            for (variable, plots) in params.vars
                for p in plots
                    autolimits!(axes_dict[(variable, p)])
                end
            end
        end
    end
    MakieLayout.trim!(layout)
    TurkieCallback(scene, data, axes_dict, params, iter)
end

function addIO!(cb::TurkieCallback, io)
    cb.params.params[:io] = io
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
    if haskey(cb.params.params, :io) 
        #error("You need to pass the IO object via `addIO!(cb, io)`")
        recordframe!(cb.params.params[:io])
    end
end

end
