include("schnapsen.jl")
include("alphabeta.jl")
include("pvs.jl")

function perft_debug(s::Schnapsen, depth::Int)
    if depth == 1
        return length(get_moves(s))
    end
    n = 0
    _s = deepcopy(s)
    u = Undo()
    for m in get_moves(s)
        make_move!(s, m, u)
        undo_move!(s, m, u)
        if s != _s
            println("board:")
            print_schnapsen(_s)
            println("\n\nmove:")
            println(m)
            println("\n\nboard after move + undo:")
            print_schnapsen(s)
            println("\n\nundo:")
            println(u)
            error("NO!")
        end
        make_move!(s, m, u)
        n += perft_debug(s, depth-1)
        undo_move!(s, m, u)
    end

    return n
end

perft_debug(Schnapsen(), 10)


function perft(s::Schnapsen, depth::Int, mls::Vector{MoveList}, uls::Vector{Undo})
    if is_gameover(s)
        return 1
    end

    movelist = mls[depth]
    recycle!(movelist)
    get_moves!(movelist, s)
    u = uls[depth]

    if depth == 1
        return length(movelist)
    end
    n = 0
    for m in movelist
        make_move!(s, m, u)
        n += perft(s, depth-1, mls, uls)
        undo_move!(s, m, u)
    end

    return n
end


using BenchmarkTools
mls = [MoveList() for _ in 1:20]
uls = [Undo() for _ in 1:20]
n = perft(Schnapsen(), 10, mls, uls) # 13657610 -> 26606264
@btime perft(Schnapsen(), 10, mls, uls) # 210.799 ms (17 allocations: 1.96 KiB) -> 452.518 ms (17 allocations: 1.96 KiB)

n,t, = @timed perft(Schnapsen(), 11, mls, uls)
n / t

# 38 -> 51 mio per second

@btime alphabeta(Schnapsen(), -10_000, 10_000, 20, mls, uls) # 48.057 ms (17 allocations: 1.96 KiB) -> 34.345 ms (17 allocations: 1.96 KiB)

ab = AlphaBeta(20)
go(ab, Schnapsen())
ab.n_nodes

ab = AlphaBeta(20)
@btime begin
    ab.n_nodes = 0
    go(ab, Schnapsen())
end

pvs = PVS(20)
go(pvs, Schnapsen())
pvs.n_nodes

pvs = PVS(20)
@btime begin
    ab.n_nodes = 0
    go(pvs, Schnapsen())
end

import JLD2
JLD2.@load "showdowntable.jld2" table


go(ab, Schnapsen())


s = Schnapsen()
s.lock = 1

@time perft(Schnapsen(), 12)

@time perft2(Schnapsen(), 12)

@profiler perft(Schnapsen(), 11, mls)

@profiler alphabeta(Schnapsen(), -10_000, 10_000, 20, mls, uls)
