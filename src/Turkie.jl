module Turkie

using Makie: Makie, Figure, Axis, Point2f, Label, Left
using Makie: barplot!, lines!, scatter! # Plotting tools
using Makie: Observable, lift, on # Observable tools
using Makie: recordframe! # Recording tools
using Colors, ColorSchemes # Colors tools
using KernelDensity # To be able to give a KDE
using OnlineStats # Estimators
using Turing.DynamicPPL: AbstractPPL, VarInfo, Model
using Turing: DynamicPPL
using Turing: Inference 

using MCMCChains

export TurkieCallback
export addIO!, record

# Uses the colorblind scheme of seaborn by default
const std_colors = ColorSchemes.seaborn_colorblind

# Utils
name(s::Symbol) = name(Val(s))
name(::Val{T}) where {T} = string(T)
name(s::OnlineStat) = string(nameof(typeof(s)))

include(joinpath("live_sampling", "turkie_callback.jl"))
include(joinpath("chain_plotting", "makie_plots.jl"))


end
