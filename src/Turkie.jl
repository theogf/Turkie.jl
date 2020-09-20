module Turkie

using Makie
using AbstractPlotting
using AbstractPlotting.MakieLayout
using Colors, ColorSchemes
using KernelDensity
using OnlineStats
using StatsBase
using Turing

export TurkieParams
export TurkieCallback

const std_colors = ColorSchemes.seaborn_colorblind

struct TurkieParams
    vars::Dict{Symbol, Any}
    params::Dict{Symbol, Any}
end

function TurkieParams(model; kwargs...) # Only needed for Turing models
    variables = Turing.VarInfo(model).metadata
    return TurkieParams(Dict(Pair.(keys(variables), Ref([:trace, :histkde, :mean, :var, :autocov]))); kwargs...)
end

function TurkieParams(varsdict::Dict; kwargs...)
    return TurkieParams(varsdict, Dict(kwargs...))
end

function expand_extrema(xs)
    xmin, xmax = xs
    diffx = xmax - xmin
    xmin = xmin - 0.1 * abs(diffx)
    xmax = xmax + 0.1 * abs(diffx)
    return (xmin, xmax)
end

struct TurkieCallback
    scene
    data::Dict
    axes_dict::Dict
    params::TurkieParams
    iter::Observable{Int64}
end

function TurkieCallback(params::TurkieParams)
# Create a scene and a layout
    outer_padding = 5
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    display(scene)

    nbins = get!(params.params, :nbins, 100)
    window = min(get!(params.params, :window, 1000), 1000)
    b = get!(params.params, :b, 20)

    n_rows = length(keys(params.vars))
    n_cols = maximum(length.(values(params.vars))) 
    n_plots = n_rows * n_cols
    iter = Node(0)
    data = Dict{Symbol, MovingWindow}(:iter => MovingWindow(window, Int64))
    axes_dict = Dict()
    for (i, (variable, plots)) in enumerate(params.vars)
        data[variable] = MovingWindow(window, Float32)
        axes_dict[(variable, :varname)] = layout[i, 1, Left()] = LText(scene, string(variable), textsize = 30)
        axes_dict[(variable, :varname)].padding = (0, 50, 0, 0)
        for (j, p) in enumerate(plots)
            axes_dict[(variable, p)] = layout[i, j] = LAxis(scene, title = "$p")
            if p == :trace
                trace = lift(iter; init = [Point2f0(0, 0f0)]) do i
                    Point2f0.(value(data[:iter]), value(data[variable]))
                end
                lines!(axes_dict[(variable, p)], trace, color = std_colors[i]; linewidth = 3.0)
            elseif p == :hist
                # Most of this can be removed once StatsMakie has been up to date
                hist = lift(iter; init = KHist(nbins, Float32)) do i
                    fit!(hist[], last(value(data[variable])))
                end
                hist_vals = lift(hist; init = Point2f0.(range(0, 1, length = nbins), zeros(Float32, nbins))) do h
                    N = sum(last, h.bins)
                    return Point2f0.(first.(h.bins), last.(h.bins) ./ N)
                end
                
                barplot!(axes_dict[(variable, p)], hist_vals, color = std_colors[i])
                # barplot!(axes_dict[(variable, p)], hist, color = std_colors[i]; linewidth = 3.0)
            elseif p == :histkde
                interpkde = lift(iter; init = InterpKDE(kde([1f0]))) do i
                    InterpKDE(kde(value(data[variable])))
                end
                xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
                    range(expand_extrema(extrema(value(data[variable])))..., length = 200)
                end
                kde_pdf = lift(xs) do xs
                    pdf.(Ref(interpkde[]), xs)
                end
                hist = lift(iter; init = KHist(nbins, Float32)) do i
                    fit!(hist[], last(value(data[variable])))
                end
                hist_vals = lift(hist; init = Point2f0.(range(0, 1, length = nbins), zeros(Float32, nbins))) do h
                    edges, weights =OnlineStats.xy(h)
                    weights = nobs(h) > 1 ? weights / OnlineStats.area(h) : weights
                    return Point2f0.(edges, weights)
                end
                barplot!(axes_dict[(variable, p)], hist_vals, color = RGBA(std_colors[i], 0.8))
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
            
            elseif p == :mean
                obs_mean = lift(iter; init = Mean(Float32)) do i
                    fit!(obs_mean[], last(value(data[variable])))
                end
                vals_mean = lift(obs_mean; init = MovingWindow(window, Float32)) do m
                    fit!(vals_mean[], value(m))
                end
                points_mean = lift(vals_mean; init = [Point2f0(0, 0)]) do v
                    Point2f0.(value(data[:iter]), value(v))
                end
                lines!(axes_dict[(variable, p)], points_mean, color = std_colors[i], linewidth = 3.0)
            elseif p == :var
                obs_var = lift(iter; init = Variance(Float32)) do i
                    fit!(obs_var[], last(value(data[variable])))
                end
                vals_var = lift(obs_var; init = MovingWindow(window, Float32)) do v
                    fit!(vals_var[], Float32(value(v)))
                end
                points_var = lift(vals_var; init = [Point2f0(0, 0)]) do v
                    Point2f0.(value(data[:iter]), value(v))
                end
                lines!(axes_dict[(variable, p)], points_var, color = std_colors[i], linewidth = 3.0)
            elseif p == :autocov
                obs_autocov = lift(iter; init = AutoCov(b, Float32)) do i
                    fit!(obs_autocov[], last(value(data[variable])))
                end
                vals_autocov = lift(obs_autocov; init = zeros(Float32, b + 1)) do v
                    value(v)
                end
                lines!(axes_dict[(variable, p)], 0:b, vals_autocov, color = std_colors[i], linewidth = 3.0)
                ylims!(axes_dict[(variable, p)] , (-0.2, 1.2))
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
    TurkieCallback(scene, data, axes_dict, params, iter)
end

function (cb::TurkieCallback)(rng, model, sampler, transition, iteration)
    fit!(cb.data[:iter], iteration)
    for (vals, ks) in values(transition.θ)
        for (k, val) in zip(ks, vals)
            fit!(cb.data[Symbol(k)], Float32(val))
        end
    end
    cb.iter[] += 1
end

end
