

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
            println(_s)
            println("\n\nmove:")
            println(m)
            println("\n\nboard after move + undo:")
            println(s)
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


function perft(s::Schnapsen, depth::Int)
    if is_gameover(s)
        return 1
    end
    if depth == 1
        return length(get_moves(s))
    end
    n = 0
    for m in get_moves(s)
        u = make_move!(s, m)
        n += perft(s, depth-1)
        undo_move!(s, m, u)
    end

    return n
end

function perft2(s::Schnapsen, depth::Int)
    if is_gameover(s) || length(s.talon) == 0 || is_locked(s)
        return 1
    end
    if depth == 1
        return length(get_moves(s))
    end
    n = 0
    for m in get_moves(s)
        u = make_move!(s, m)
        n += perft2(s, depth-1)
        undo_move!(s, m, u)
    end

    return n
end


using BenchmarkTools
n = perft(Schnapsen(), 10)
@btime perft(Schnapsen(), 10)

n,t, = @timed perft(Schnapsen(), 11)
n / t

# 15 mio per second

s = Schnapsen()
s.lock = 1

@time perft(Schnapsen(), 12)

@time perft2(Schnapsen(), 12)
