include("schnapsen.jl")
include("alphabeta.jl")
include("game.jl")

function perft_debug(s::Schnapsen, depth::Int)
    if depth == 1
        return length(get_moves(s))
    end
    n = 0
    _s = deepcopy(s)
    for m in get_moves(s)
        u = make_move!(s, m)
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
        u = make_move!(s, m)
        n += perft_debug(s, depth-1)
        undo_move!(s, m, u)
    end

    return n
end

perft_debug(Schnapsen(), 10)


function perft(s::Schnapsen, depth::Int, mls::Vector{MoveList})
    if is_gameover(s)
        return 1
    end

    movelist = mls[depth]
    recycle!(movelist)
    get_moves!(movelist, s)

    if depth == 1
        return length(movelist)
    end
    n = 0
    for m in movelist
        u = make_move!(s, m)
        n += perft(s, depth-1, mls)
        undo_move!(s, m, u)
    end

    return n
end


using BenchmarkTools
mls = [MoveList() for _ in 1:20]
n = perft(Schnapsen(), 10, mls) # 13657610
@btime perft(Schnapsen(), 10, mls) # 887.921 ms (15287080 allocations: 1.39 GiB) -> 275.501 ms (4167017 allocations: 381.50 MiB)

n,t, = @timed perft(Schnapsen(), 11, mls)
n / t

# 15 mio per second

@btime alphabeta(Schnapsen(), -10_000, 10_000, 20) # 99.562 ms (1329217 allocations: 108.28 MiB)

s = Schnapsen()
s.lock = 1

@time perft(Schnapsen(), 12)

@time perft2(Schnapsen(), 12)

@profiler perft(Schnapsen(), 11, mls)
