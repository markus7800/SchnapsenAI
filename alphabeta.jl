


function alphabeta(s::Schnapsen, α::Int, β::Int, depth::Int, mls::Vector{MoveList}, uls::Vector{Undo})::Int
    if is_gameover(s)
        mult = winner(s) == 1 ? 1 : -1
        return mult * winscore(s) * 1000
    end
    if depth == 0
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = mls[depth]
    recycle!(ms)
    get_moves!(ms, s)
    u = uls[depth]

    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), alg=Base.Sort.QuickSort, rev=true)

    if s.player_to_move == 1
        val = -10_000
        for m in ms
            make_move!(s, m, u)
            val = max(val, alphabeta(s, α, β, depth-1, mls, uls))
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return val
    else
        val = 10_000
        for m in ms
            make_move!(s, m, u)
            val = min(val, alphabeta(s, α, β, depth-1, mls, uls))
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return val
    end
end

mutable struct AlphaBeta
    depth::Int
    mls::Vector{MoveList}
    uls::Vector{Undo}
    showdown_table::Union{Dict{Tuple{Cards, Cards}, Tuple{Int,Int}}, Missing}
    n_nodes::Int
    function AlphaBeta(depth::Int; showdown_table=missing)
        return new(
            depth,
            [MoveList() for _ in 1:20],
            [Undo() for _ in 1:20],
            showdown_table,
            0,
        )
    end
end

function go(ab::AlphaBeta, s::Schnapsen)::Int
    return alphabeta!(ab, s, -10_000, 10_000, ab.depth)
end

function alphabeta!(ab::AlphaBeta, s::Schnapsen, α::Int, β::Int, depth::Int)::Int
    ab.n_nodes += 1
    if is_gameover(s)
        mult = winner(s) == 1 ? 1 : -1
        return mult * winscore(s) * 1000
    end
    if depth == 0
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = ab.mls[depth]
    recycle!(ms)
    get_moves!(ms, s)
    u = ab.uls[depth]

    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), alg=Base.Sort.QuickSort, rev=true)

    if s.player_to_move == 1
        #val = -10_000
        for m in ms
            make_move!(s, m, u)
            #val = max(val, alphabeta!(ab, s, α, β, depth-1))
            val = alphabeta!(ab, s, α, β, depth-1)
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && return β
        end
        return α
    else
        #val = 10_000
        for m in ms
            make_move!(s, m, u)
            # val = min(val, alphabeta!(ab, s, α, β, depth-1))
            val = alphabeta!(ab, s, α, β, depth-1)
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && return α
        end
        return β
    end
end


# s = Schnapsen()
# using BenchmarkTools
# @btime alphabeta(s, -10_000, 10_000, 20)
#
# vals = begin
#     vals = Int[]
#     @progress for seed in 1:10_000
#         s = Schnapsen(seed)
#         v = alphabeta(s, -10_000, 10_000, 4)
#         push!(vals, v)
#     end
#     vals
# end

# using Plots
#
# histogram(vals)
# no_wins = vals[-100 .< vals .& vals .< 100]
# histogram(no_wins)
#
# mean(vals)
# mean(no_wins)
#
# for n in 0:9
#     println(binomial(15-n, 5) * factorial(10-n-1))
# end

function search(s::Schnapsen, depth::Int)
    rootmoves = get_moves(s)
    values = Int[]
    for m in rootmoves
        u = make_move!(s, m)
        val = alphabeta(s,-10_000, 10_000, depth-1)
        push!(values, val)
        undo_move!(s, m, u)
    end

    return collect(zip(rootmoves, values))
end

function best_move(s::Schnapsen)
    player = s.player_to_move
    rev = player == 1
    ranked_moves = search(s, 20)
    sort!(ranked_moves, lt=(x,y)->x[2]<y[2], rev=rev)
    bestmove, value = ranked_moves[1]
    println("Found bestmove $bestmove with value $value for player $player.")
    return bestmove
end

# s = Schnapsen()
#
# res = search(s, 20)
#
# best_move(s)
#
# playloop(s, player1=best_move, player2=best_move)
#
#
# cards_known = 6
# n_opp_hand = binomial(20-cards_known, 5)
# n_talon = factorial(20-cards_known-5)
#
# total = n_opp_hand * n_talon
#
# depth = 10
# n_talon / factorial(4)
# eff = total / factorial(20-cards_known-5 - (depth-5))
#
# @btime alphabeta(Schnapsen(), -10_000, 10_000, 20)
