function onlineplot!(axis, stat::Symbol, iter, data, iterations, i, j)
    onlineplot!(axis, Val(stat), iter, data, iterations, i, j)
end

function onlineplot!(axis, stat::Val{:trace}, iter, data, iterations, i, j)
    trace = lift(iter; init = [Point2f0(0, 0f0)]) do i
        Point2f0.(value(iterations), value(data))
    end
    lines!(axis, trace, color = std_colors[i]; linewidth = 3.0)
end

function onlineplot!(axis, stat::KHist, iter, data, iterations, i, j)
    nbins = stat.k
    hist = lift(iter; init = KHist(nbins, Float32)) do i
        fit!(hist[], last(value(data)))
    end
    hist_vals = lift(hist; init = Point2f0.(range(0, 1, length = nbins), zeros(Float32, nbins))) do h
        edges, weights = OnlineStats.xy(h)
        weights = nobs(h) > 1 ? weights / OnlineStats.area(h) : weights
        return Point2f0.(edges, weights)
    end
    barplot!(axis, hist_vals, color = std_colors[i])
end

function onlineplot!(axis, stat::Val{:kde}, iter, data, iterations, i, j)
     interpkde = lift(iter; init = InterpKDE(kde([1f0]))) do i
        InterpKDE(kde(value(data)))
    end
    xs = lift(iter; init = range(0.0, 2.0, length = 200)) do i
        range(expand_extrema(extrema(value(data)))..., length = 200)
    end
    kde_pdf = lift(xs) do xs
        pdf.(Ref(interpkde[]), xs)
    end
    lines!(axis, xs, kde_pdf, color = std_colors[i], linewidth = 3.0)
end

function onlineplot!(axis, stat::Val{:histkde}, iter, data, iterations, i, j)
    onlineplot!(axis, KHist(50), iter, data, iterations, i, j)
    onlineplot!(axis, Val(:kde), iter, data, iterations, i, j)
end

onlineplot!(axis, stat::Val{:mean}, args...) = onlineplot!(axis, Mean(), args...)

function onlineplot!(axis, stat::Mean, iter, data, iterations, i, j)
    window = data.b
    obs_mean = lift(iter; init = Mean(Float32)) do i
        fit!(obs_mean[], last(value(data)))
    end
    vals_mean = lift(obs_mean; init = MovingWindow(window, Float32)) do m
        fit!(vals_mean[], value(m))
    end
    points_mean = lift(vals_mean; init = [Point2f0(0, 0)]) do v
        Point2f0.(value(iterations), value(v))
    end
    lines!(axis, points_mean, color = std_colors[i], linewidth = 3.0)
end

onlineplot!(axis, stat::Val{:var}, args...) = onlineplot!(axis, Variance(), args...)

function onlineplot!(axis, stat::Variance, iter, data, iterations, i, j)
    window = data.b
    obs_var = lift(iter; init = Variance(Float32)) do i
        fit!(obs_var[], last(value(data)))
    end
    vals_var = lift(obs_var; init = MovingWindow(window, Float32)) do v
        fit!(vals_var[], Float32(value(v)))
    end
    points_var = lift(vals_var; init = [Point2f0(0, 0)]) do v
        Point2f0.(value(iterations), value(v))
    end
    lines!(axis, points_var, color = std_colors[i], linewidth = 3.0)
end

onlineplot!(axis, stat::Val{:autocov}, args...) = onlineplot!(axis, AutoCov(50), args...)

function onlineplot!(axis, stat::AutoCov, iter, data, iterations, i, j)
    b = length(stat.cross)
    obs_autocov = lift(iter; init = AutoCov(b, Float32)) do i
        fit!(obs_autocov[], last(value(data)))
    end
    vals_autocov = lift(obs_autocov; init = zeros(Float32, b + 1)) do v
        value(v)
    end
    scatter!(Point2f0.([0.0, 0.0], [-0.2, 1.2]), color = RGBA(0.0, 0.0, 0.0, 0.0)) # Invisible points to keep limits fixed
    lines!(axis, 0:b, vals_autocov, color = std_colors[i], linewidth = 3.0)
end