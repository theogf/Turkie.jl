using Documenter

# Print `@debug` statements (https://github.com/JuliaDocs/Documenter.jl/issues/955)
if haskey(ENV, "GITHUB_ACTIONS")
    ENV["JULIA_DEBUG"] = "Documenter"
end

using Turkie

makedocs(;
    sitename="Turkie",
    format=Documenter.HTML(),
    modules=[Turkie],
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ],
    strict=true,
    checkdocs=:exports,
)

deploydocs(;
    repo="github.com/theogf/Turkie.jl.git", push_preview=true
)
