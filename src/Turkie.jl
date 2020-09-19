module Turkie

using Makie
using AbstractPlotting
using AbstractPlotting.MakieLayout
using Colors, ColorSchemes
using KernelDensity
using OnlineStats
using StatsBase
using Turing

export TurkParams
export make_callback
export sample_and_viz

const std_colors = ColorSchemes.seaborn_colorblind


struct TurkParams
    vars::Dict{Symbol, Any}
    params::Dict{Symbol, Any}
end

function TurkParams(model; kwargs...) # Only needed for Turing models
    variables = Turing.VarInfo(model).metadata
    return TurkParams(Dict(Pair.(keys(variables), Ref([:trace, :histkde]))); kwargs...)
end

function TurkParams(varsdict::Dict; kwargs...)
    return TurkParams(varsdict, Dict(kwargs...))
end

function expand_extrema(xs)
    xmin, xmax = xs
    xmin = xmin - 0.1 * abs(xmin)
    xmax = xmax + 0.1 * abs(xmax)
    return (xmin, xmax)
end

function make_callback(params::TurkParams)
# Create a scene and a layout
    outer_padding = 5
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    display(scene)

    n_rows = length(keys(params.vars))
    n_cols = maximum(length.(values(params.vars))) 
    n_plots = n_rows * n_cols
    nbins = get!(params.params, :nbins, 100)
    iter = Node(0)
    data = Dict{Symbol, Any}(:iter => Int64[])
    axes_dict = Dict()
    for (i, (variable, plots)) in enumerate(params.vars)
        data[variable] = Real[]
        axes_dict[(variable, :varname)] = layout[i, 1, Left()] = LText(scene, string(variable), textsize = 30)
        axes_dict[(variable, :varname)].padding = (0, 50, 0, 0)
        for (j, p) in enumerate(plots)
            axes_dict[(variable, p)] = layout[i, j] = LAxis(scene, title = "$p")
            if p == :trace
                trace = lift(iter; init = [Point2f0(0, 0)]) do i
                    Point2f0.(data[:iter], data[variable])
                end
                lines!(axes_dict[(variable, p)], trace, color = std_colors[i]; linewidth = 3.0)
            elseif p == :hist
                # Most of this can be removed once StatsMakie has been up to date
                hist = lift(iter; init = StatsBase.normalize(fit(Histogram, [1.0, 2.0]), mode = :pdf)) do i
                    N = length(data[variable])
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = nbins); mode = :pdf)
                end
                barplot!(axes_dict[(variable, p)], hist, color = std_colors[i]; linewidth = 3.0)
            elseif p == :histkde
                interpkde = lift(iter; init = InterpKDE(kde([1.0]))) do i
                    InterpKDE(kde(data[variable]))
                end
                xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
                    range(expand_extrema(extrema(data[variable]))..., length = 200)
                end
                kde_pdf = lift(xs) do xs
                    pdf.(Ref(interpkde[]), xs)
                end
                hist = lift(iter; init = StatsBase.normalize(fit(Histogram, [1.0, 2.0]); mode = :pdf)) do i
                    N = length(data[variable])
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = nbins); mode = :pdf)
                end
                barplot!(axes_dict[(variable, p)], hist, color = RGBA(std_colors[i], 0.8))
                lines!(axes_dict[(variable, p)], xs, kde_pdf, color = std_colors[i], linewidth = 3.0)
            elseif p == :kde
                interpkde = lift(iter; init = InterpKDE(kde([1.0]))) do i
                    InterpKDE(kde(data[variable]))
                end
                xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
                    range(expand_extrema(extrema(data[variable]))..., length = 200)
                end
                kde_pdf = lift(xs) do xs
                    pdf.(Ref(interpkde[]), xs)
                end
                lines!(axes_dict[(variable, p)], xs, kde_pdf, color = std_colors[i]; linewidth = 3.0)
            end
        end
    end
    lift(iter) do i
        if i > 10 # To deal with autolimits a certain number of samples are needed
            for (variable, plots) in params.vars
                for p in plots
                    autolimits!(axes_dict[(variable, p)])
                    tightlimits!(axes_dict[(variable, p)])
                end
            end
        end
    end
    MakieLayout.trim!(layout)
    return function callback(rng, model, sampler, transition, iteration)
        push!(data[:iter], iteration) 
        for (vals, ks) in values(transition.θ)
            for (k, val) in zip(ks, vals)
                push!(data[Symbol(k)], val)
            end
        end
        iter[] += 1
    end, scene
end

function sample_and_viz(params::TurkParams, args...; kwargs...)
    # Create a scene and a layout
    outer_padding = 30
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    display(scene)

    n_rows = length(keys(params.vars))
    n_cols = maximum(length.(values(params.vars))) + 1
    n_plots = n_rows * n_cols
    nbins = get!(params.params, :nbins, 100)
    iter = Node(0)
    data = Dict{Symbol, Any}(:iter => Int64[])
    axes = Dict()
    for (i, (variable, plots)) in enumerate(params.vars)
        data[variable] = Real[]
        axes[(variable, )] = layout[i, j] = LAxis(scene, title = "")
        for (j, p) in enumerate(plots)
            axes[(variable, p)] = layout[i+1, j] = LAxis(scene, title = "$variable : $p")
            if p == :trace
                trace = lift(iter; init = [Point2f0(0, 0)]) do i
                    Point2f0.(data[:iter], data[variable])
                end
                lines!(axes[(variable, p)], trace, color = std_colors[i]; linewidth = 3.0)
            elseif p == :hist
                # Most of this can be removed once StatsMakie has been up to date
                hist = lift(iter; init = StatsBase.normalize(fit(Histogram, [1.0, 2.0]), mode = :pdf)) do i
                    N = length(data[variable])
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = nbins); mode = :pdf)
                end
                barplot!(axes[(variable, p)], hist, color = std_colors[i]; linewidth = 3.0)
            elseif p == :histkde
                interpkde = lift(iter; init = InterpKDE(kde([1.0]))) do i
                    InterpKDE(kde(data[variable]))
                end
                xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
                    range(expand_extrema(extrema(data[variable]))..., length = 200)
                end
                kde_pdf = lift(xs) do xs
                    pdf.(Ref(interpkde[]), xs)
                end
                hist = lift(iter; init = StatsBase.normalize(fit(Histogram, [1.0, 2.0]); mode = :pdf)) do i
                    N = length(data[variable])
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = nbins); mode = :pdf)
                end
                barplot!(axes[(variable, p)], hist, color = RGBA(std_colors[i], 0.8))
                lines!(axes[(variable, p)], xs, kde_pdf, color = std_colors[i], linewidth = 3.0)
            elseif p == :kde
                interpkde = lift(iter; init = InterpKDE(kde([1.0]))) do i
                    InterpKDE(kde(data[variable]))
                end
                xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
                    range(expand_extrema(extrema(data[variable]))..., length = 200)
                end
                kde_pdf = lift(xs) do xs
                    pdf.(Ref(interpkde[]), xs)
                end
                lines!(axes[(variable, p)], xs, kde_pdf, color = std_colors[i]; linewidth = 3.0)
            end
        end
    end
    lift(iter) do i
        if i > 10 # To deal with autolimits a certain number of samples are needed
            for (variable, plots) in params.vars
                for p in plots
                    autolimits!(axes[(variable, p)])
                    tightlimits!(axes[(variable, p)])
                end
            end
        end
    end
    function callback(rng, model, sampler, transition, iteration)
        push!(data[:iter], iteration) 
        for (vals, ks) in values(transition.θ)
            for (k, val) in zip(ks, vals)
                push!(data[Symbol(k)], val)
            end
        end
        iter[] += 1
    end
    chain = sample(args...; callback=callback, kwargs...)
    return chain, scene
end

end
