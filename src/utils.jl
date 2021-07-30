name(s::Symbol) = name(Val(s))
name(::Val{T}) where {T} = string(T)
name(s::OnlineStat) = string(nameof(typeof(s)))

function Base.show(io::IO, cb::TurkieCallback)
    show(io, cb.figure)
end

function Base.show(io::IO, ::MIME"text/plain", cb::TurkieCallback)
    print(io, "TurkieCallback tracking the following variables:\n")
    for v in keys(cb.vars)
        print(io, "  ", v, "\t=> [")
        for s in cb.vars[v][1:end-1]
            print(io, name(s), ", ")
        end
        print(io, name(cb.vars[v][end]), "]\n")
    end
end