function onlineplot!(fig, axis_dict, stats::AbstractVector, iter, data, variable, i)
    for (j, stat) in enumerate(stats)
        axis_dict[(variable, stat)] = fig[i, j] = Axis(fig, title="$(name(stat))")
        limits!(axis_dict[(variable, stat)], 0.0, 10.0, -1.0, 1.0)
        onlineplot!(axis_dict[(variable, stat)], stat, iter, data[variable], data[:iter], i, j)
        tight_ticklabel_spacing!(axis_dict[(variable, stat)])
    end
end

function onlineplot!(axis, stat::Symbol, args...)
    onlineplot!(axis, Val(stat), args...)
end

onlineplot!(axis, ::Val{:mean}, args...) = onlineplot!(axis, Mean(), args...)

onlineplot!(axis, ::Val{:var}, args...) = onlineplot!(axis, Variance(), args...)

onlineplot!(axis, ::Val{:autocov}, args...) = onlineplot!(axis, AutoCov(20), args...)

onlineplot!(axis, ::Val{:hist}, args...) = onlineplot!(axis, KHist(50, Float32), args...)

# Generic fallback for OnlineStat objects
function onlineplot!(axis, stat::T, iter, data, iterations, i, j) where {T<:OnlineStat}
    window = data.b
    @eval TStat = $(nameof(T))
    stat = Observable(TStat(Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data)))
    end
    statvals = Observable(MovingWindow(window, Float32))
    on(stat) do s
        statvals[] = fit!(statvals[], Float32(value(s)))
    end
    statpoints = map!(Observable(Point2f0.([0], [0])), statvals)  do v
        Point2f0.(value(iterations), value(v))
    end
    lines!(axis, statpoints, color = std_colors[i], linewidth = 3.0)
end

function onlineplot!(axis, ::Val{:trace}, iter, data, iterations, i, j)
    trace = map!(Observable([Point2f0(0, 0)]), iter) do _
        Point2f0.(value(iterations), value(data))
    end
    lines!(axis, trace, color = std_colors[i]; linewidth = 3.0)
end

function onlineplot!(axis, stat::KHist, iter, data, iterations, i, j)
    nbins = stat.k
    stat = Observable(KHist(nbins, Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data)))
    end
    hist_vals = Node(Point2f0.(collect(range(0f0, 1f0, length=nbins)), zeros(Float32, nbins)))
    on(stat) do h
        edges, weights = OnlineStats.xy(h)
        weights = nobs(h) > 1 ? weights / OnlineStats.area(h) : weights
        hist_vals[] = Point2f0.(edges, weights)
    end
    barplot!(axis, hist_vals; color=std_colors[i])
    # barplot!(axis, rand(4), rand(4))
end

function expand_extrema(xs)
    xmin, xmax = xs
    diffx = xmax - xmin
    xmin = xmin - 0.1 * abs(diffx)
    xmax = xmax + 0.1 * abs(diffx)
    return (xmin, xmax)
end

function onlineplot!(axis, ::Val{:kde}, iter, data, iterations, i, j)
    interpkde = Observable(InterpKDE(kde([1f0])))
    on(iter) do _
        interpkde[] = InterpKDE(kde(value(data)))
    end
    xs = Observable(range(0, 2, length=10))
    on(iter) do _
        xs[] = range(expand_extrema(extrema(value(data)))..., length = 200)
    end
    kde_pdf = lift(xs) do xs
        pdf.(Ref(interpkde[]), xs)
    end
    lines!(axis, xs, kde_pdf, color = std_colors[i], linewidth = 3.0)
end

name(s::Val{:histkde}) = "Hist. + KDE"

function onlineplot!(axis, ::Val{:histkde}, iter, data, iterations, i, j)
    onlineplot!(axis, KHist(50), iter, data, iterations, i, j)
    onlineplot!(axis, Val(:kde), iter, data, iterations, i, j)
end

function onlineplot!(axis, stat::AutoCov, iter, data, iterations, i, j)
    b = length(stat.cross)
    stat = Observable(AutoCov(b, Float32))
    on(iter) do _
        stat[] = fit!(stat[], last(value(data)))
    end
    statvals = map!(Observable(zeros(Float32, b + 1)), stat) do s
        value(s)
    end
    scatter!(axis, Point2f0.([0.0, b], [-0.1, 1.0]), markersize = 0.0, color = RGBA(0.0, 0.0, 0.0, 0.0)) # Invisible points to keep limits fixed
    lines!(axis, 0:b, statvals, color = std_colors[i], linewidth = 3.0)
end
