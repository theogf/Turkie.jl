function onlineplot!(fig::Figure, axis_dict::AbstractDict, stats::AbstractVector, stats_dict::AbstractDict, iter, data, variable, i)
    # Iter over all the stats for a given variable, create an axis and add 
    # the appropriate plots on it.
    for (j, stat) in enumerate(stats)
        axis_dict[(variable, stat)] = fig[i, j] = Axis(fig, title="$(name(stat))")
        Makie.limits!(axis_dict[(variable, stat)], 0.0, 10.0, -1.0, 1.0)
        stats_dict[(variable, stat)] = []
        onlineplot!(axis_dict[(variable, stat)], stat, stats_dict[(variable, stat)], iter, data[variable], data[:iter], i, j)
        # tight_ticklabel_spacing!(axis_dict[(variable, stat)])
    end
end

# Reset the saved stats to be able to refresh the plots when wanted
reset!(::Any, ::Any) = nothing # Default behavior is to do nothing
reset!(stats, stat::Symbol) = reset!(stats, Val(stat))
reset!(stats, ::Val{:mean}) = reset!(stats, Mean())
reset!(stats, ::Val{:var}) = reset!(stats, Variance())
reset!(stats, ::Val{:autocov}) = reset!(stats, AutoCov(20))
reset!(stats, ::Val{:hist}) = reset!(stats, KHist(50, Float32))

function onlineplot!(axis::Axis, stat::Symbol, args...)
    onlineplot!(axis, Val(stat), args...)
end

onlineplot!(axis, ::Val{:mean}, args...) = onlineplot!(axis, Mean(), args...)

onlineplot!(axis, ::Val{:var}, args...) = onlineplot!(axis, Variance(), args...)

onlineplot!(axis, ::Val{:autocov}, args...) = onlineplot!(axis, AutoCov(20), args...)

onlineplot!(axis, ::Val{:hist}, args...) = onlineplot!(axis, KHist(50, Float32), args...)

# Generic fallback for OnlineStat objects
function onlineplot!(axis, stat::T, stats, iter, data, iterations, i, j) where {T<:OnlineStat}
    window = data[].b
    TStat = Base.typename(T).wrapper
    # Create an observable based on the given stat
    stat = Observable(TStat(Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data[])))
    end
    push!(stats, stat)
    # Create a moving window on this value
    statvals = Observable(MovingWindow(window, Float32))
    on(stat) do s
        statvals[] = fit!(statvals[], Float32(value(s)))
    end
    push!(stats, statvals)
    # Pass this observable to create points to pass to Makie
    statpoints = map!(Observable(Point2f.([0], [0])), statvals) do v
        Point2f.(value(iterations[]), value(v))
    end
    lines!(axis, statpoints, color = std_colors[i], linewidth = 3.0)
end

function reset!(stats, stat::T) where {T<:OnlineStat}
    TStat = Base.typename(T).wrapper
    stats[1].val = TStat(Float32) # Represent the actual stat
    stats[2].val = MovingWindow(stats[2][].b, Float32) # Represent the moving window on the stat
end

function onlineplot!(axis, ::Val{:trace}, stats, iter, data, iterations, i, j)
    trace = map!(Observable([Point2f(0, 0)]), iter) do _
        Point2f.(value(iterations[]), value(data[]))
    end
    lines!(axis, trace, color = std_colors[i]; linewidth = 3.0)
end

function onlineplot!(axis, stat::KHist, stats, iter, data, iterations, i, j)
    nbins = stat.k
    stat = Observable(KHist(nbins, Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data[])))
    end
    hist_vals = Observable(Point2f.(collect(range(0f0, 1f0, length=nbins)), zeros(Float32, nbins)))
    push!(stats, stat)
    on(stat) do h
        edges, weights = OnlineStats.xy(h)
        weights = nobs(h) > 1 ? weights / OnlineStats.area(h) : weights
        hist_vals[] = Point2f.(edges, weights)
    end
    push!(stats, hist_vals)
    barplot!(axis, hist_vals; color=std_colors[i])
end

function reset!(stats, stat::KHist)
    nbins = stat.k
    stats[1].val = KHist(nbins, Float32)
    stats[2].val = Point2f.(collect(range(0f0, 1f0, length=nbins)), zeros(Float32, nbins))
end

function expand_extrema(xs)
    xmin, xmax = xs
    diffx = xmax - xmin
    xmin = xmin - 0.1 * abs(diffx)
    xmax = xmax + 0.1 * abs(diffx)
    return (xmin, xmax)
end

function onlineplot!(axis, ::Val{:kde}, stats, iter, data, iterations, i, j)
    interpkde = Observable(InterpKDE(kde([1f0])))
    on(iter) do _
        interpkde[] = InterpKDE(kde(value(data[])))
    end
    push!(stats, interpkde)
    xs = Observable(range(0, 2, length=10))
    on(iter) do _
        xs[] = range(expand_extrema(extrema(value(data[])))..., length = 200)
    end
    push!(stats, xs)
    kde_pdf = lift(xs) do xs
        pdf.(Ref(interpkde[]), xs)
    end
    lines!(axis, xs, kde_pdf, color = std_colors[i], linewidth = 3.0)
end

function reset!(stats, ::Val{:kde})
    stats[1].val = InterpKDE(kde([1f0]))
    stats[2].val = range(0, 2, length=10)
end

name(s::Val{:histkde}) = "Hist. + KDE"

function onlineplot!(axis, ::Val{:histkde}, stats, iter, data, iterations, i, j)
    onlineplot!(axis, KHist(50), stats, iter, data, iterations, i, j)
    onlineplot!(axis, Val(:kde), stats, iter, data, iterations, i, j)
end

function reset!(stats, ::Val{:histkde})
    reset!(stats[1:2], KHist(50))
    reset!(stats[3:end], Val(:kde))
end

function onlineplot!(axis, stat::AutoCov, stats, iter, data, iterations, i, j)
    b = length(stat.cross) - 1
    stat = Observable(AutoCov(b, Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data[])))
    end
    push!(stats, stat)
    statvals = map!(Observable(zeros(Float32, b + 1)), stat) do s
        value(s)
    end
    push!(stats, statvals)
    scatter!(axis, Point2f.([0.0, b], [-0.1, 1.0]), markersize = 0.0, color = RGBA(0.0, 0.0, 0.0, 0.0)) # Invisible points to keep limits fixed
    lines!(axis, 0:b, statvals, color = std_colors[i], linewidth = 3.0)
end

function reset!(stats, stat::AutoCov)
    b = length(stat.cross) - 1
    stats[1].val = AutoCov(b, Float32)
    stats[2].val = zeros(Float32, b + 1)
end
