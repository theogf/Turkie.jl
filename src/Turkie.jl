module Turkie

using Makie
using AbstractPlotting
using AbstractPlotting.MakieLayout
using Colors, ColorSchemes
using KernelDensity
using StatsBase
using Turing

export turviz
export sample_and_viz

const std_colors = ColorSchemes.seaborn_colorblind

function turviz(model)
    variables = Turing.VarInfo(model).metadata
    return Dict(Pair.(keys(variables), Ref([:trace, :histkde])))
end


function expand_extrema(xs)
    xmin, xmax = xs
    xmin = xmin - 0.1 * abs(xmin)
    xmax = xmax + 0.1 * abs(xmax)
    return (xmin, xmax)
end

function sample_and_viz(turviz::Dict, args...; kwargs...)
    # Create a scene and a layout
    outer_padding = 30
    scene, layout = layoutscene(outer_padding, resolution = (1200, 700))
    display(scene)

    n_rows = length(keys(turviz))
    n_cols = maximum(length.(values(turviz)))
    n_plots = n_rows * n_cols
    iter = Node(0)
    data = Dict{Symbol, Any}(:iter => Int64[])
    var_to_plot = Dict()
    p_to_plot = Dict()
    axes = Dict()
    for (i, (variable, plots)) in enumerate(turviz)
        var_to_plot[variable] = i
        data[variable] = Real[]
        for (j, p) in enumerate(plots)
            p_to_plot[p] = j
            axes[(variable, p)] = layout[i, j] = LAxis(scene, title = "$variable : $p")
            if p == :trace
                trace = lift(iter; init = [Point2f0(0, 0)]) do i
                    Point2f0.(data[:iter], data[variable])
                end
                lines!(axes[(variable, p)], trace, color = std_colors[i]; linewidth = 3.0)
            elseif p == :hist
                # Most of this can be removed once StatsMakie has been up to date
                hist = lift(iter; init = StatsBase.normalize(fit(Histogram, [1.0, 2.0]), mode = :pdf)) do i
                    N = length(data[variable])
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = 100); mode = :pdf)
                end
                @show hist[]
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
                    StatsBase.normalize(fit(Histogram, Float64.(data[variable]); nbins = 100); mode = :pdf)
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
            for (variable, plots) in turviz
                for p in plots
                    autolimits!(axes[(variable, p)])
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
