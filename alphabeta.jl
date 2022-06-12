

function showdown_alphabeta(s::Schnapsen, α::Int, β::Int, depth::Int)
    if depth == 0 || is_gameover(s)
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = get_moves(s)
    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), rev=true)

    if s.player_to_move == 1
        val = -1000
        for m in ms
            u = make_move!(s, m)
            val = max(val, showdown_alphabeta(s, α, β, depth-1))
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return val
    else
        val = 1000
        for m in ms
            u = make_move!(s, m)
            val = min(val, showdown_alphabeta(s, α, β, depth-1))
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return val
    end
end



function Showdown_Schnapsen(hand1::Cards, hand2::Cards, atout::Cards, player_to_move::Int)
    return Schnapsen(
        Card[],
        atout,

        hand1,
        hand2,

        NOCARD,
        player_to_move,
        false,

        0,
        0,
        0,

        0,
        0,

        player_to_move
    )
end

function Showdown_Schnapsen(s::Schnapsen)
    return Showdown_Schnapsen(s.hand1, s.hand2, s.atout, s.player_to_move)
end

function Showdown_Schnapsen(seed=0)
    s = Schnapsen(seed)
    return Showdown_Schnapsen(s.hand1, s.hand2, s.atout, s.player_to_move)
end


function choose(set::Vector, k::Int)
    n = length(set)
    if n == 0 && k > 0
        return Vector{Vector{eltype(set)}}()
    end
    if k == 0
        return [Vector{eltype(set)}()]
    end
    set = copy(set)
    s = pop!(set)

    A = choose(set, k) # exclude s
    B = map(newset -> push!(newset, s), choose(set, k-1)) # include s

    return append!(A, B)
end

using ProgressMeter

function gen_showdown_table()
    allcards = all_cards()
    hands1 = choose(allcards, 5)
    @assert length(hands1) == binomial(20, 5)

    @showprogress for hand1 in hands1
        remaining = setdiff(allcards, hand1)
        hands2 = choose(remaining, 5)
        @assert length(hands2) == binomial(15, 5)

        for hand2 in hands2
            h1 = reduce(|, hand1, init=NOCARDS)
            h2 = reduce(|, hand2, init=NOCARDS)

            s = Showdown_Schnapsen(h1, h2, HEARTS, 1)
            val = showdown_alphabeta(s, -1000, 1000, 10)
        end
    end
end

# gen_showdown_table()
#
# binomial(20, 5) * binomial(15, 5) * 0.0001 / 60
#
#
# hands1 = choose(all_cards(), 5)
#
# reduce(|, hands1[100], init=NOCARDS)
#
#
# s = Showdown_Schnapsen()
#
# @btime showdown_alphabeta(s, -10_000, 10_000, 10)
#
# s = Showdown_Schnapsen()
#
# showdown_alphabeta(s, -10_000, 10_000, 2)
# showdown_alphabeta(s, -10_000, 10_000, 4)
# showdown_alphabeta(s, -10_000, 10_000, 6)
# showdown_alphabeta(s, -10_000, 10_000, 8)
# showdown_alphabeta(s, -10_000, 10_000, 10)
#
#
# binomial(20, 5) * binomial(15, 5) * 5 / 1024^2


function alphabeta(s::Schnapsen, α::Int, β::Int, depth::Int)
    if is_gameover(s)
        mult = winner(s) == 1 ? 1 : -1
        return mult * winscore(s) * 1000
    end
    if depth == 0
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = get_moves(s)
    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), rev=true)

    if s.player_to_move == 1
        val = -10_000
        for m in ms
            u = make_move!(s, m)
            val = max(val, alphabeta(s, α, β, depth-1))
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return val
    else
        val = 10_000
        for m in ms
            u = make_move!(s, m)
            val = min(val, alphabeta(s, α, β, depth-1))
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return val
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
