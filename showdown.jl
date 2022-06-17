

function showdown_alphabeta(s::Schnapsen, α::Int, β::Int, depth::Int, mls::Vector{MoveList}, uls::Vector{Undo})
    if length(s.hand1) + length(s.hand2) == 0
        return playerscore(s, 1) - playerscore(s, 2), s.trickscore1, s.trickscore2
    end

    ms = mls[depth]
    recycle!(ms)
    get_moves!(ms, s)
    u = uls[depth]

    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), rev=true)

    t1 = 0
    t2 = 0

    if s.player_to_move == 1
        val = -1000
        for m in ms
            make_move!(s, m, u)
            val_, t1_, t2_ = showdown_alphabeta(s, α, β, depth-1, mls, uls)
            if val_ ≥ val
                val = val_
                t1 = t1_
                t2 = t2_
            end
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return val, t1, t2
    else
        val = 1000
        for m in ms
            make_move!(s, m, u)
            val_, t1_, t2_ = showdown_alphabeta(s, α, β, depth-1, mls, uls)
            if val_ ≤ val
                val = val_
                t1 = t1_
                t2 = t2_
            end
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return val, t1, t2
    end
end



function Showdown_Schnapsen!(s::Schnapsen, hand1::Cards, hand2::Cards, atout::Cards, player_to_move::Int)
    s.n_talon = 0
    s.atout = atout

    s.hand1 = hand1
    s.hand2 = hand2

    s.played_card = NOCARD
    s.lock = player_to_move
    s.stichlos = false

    s.player_to_move = player_to_move

    return s
end

function Showdown_Schnapsen!(s::Schnapsen)
    s.n_talon = 0
    s.played_card = NOCARD
    s.lock = s.player_to_move
    s.stichlos = false
    return s
end

function choose(cards::Cards, k::Int)::Vector{Cards}
    n = length(cards)
    if n == 0 && k > 0
        return Cards[]
    end
    if k == 0
        return [NOCARDS]
    end
    #cards = copy(set)
    s = first(cards) # Card
    cards = removefirst(cards)

    A = choose(cards, k) # exclude s
    B = map(newcards -> add(newcards, s), choose(cards, k-1)) # include s

    return append!(A, B)
end

using ProgressMeter

function gen_showdown_table()
    table = Dict{Tuple{Cards, Cards}, Tuple{Int,Int}}()
    s = Schnapsen()

    mls = [MoveList() for _ in 1:20]
    uls = [Undo() for _ in 1:20]

    @showprogress for hand1 in choose(ALLCARDS, 5)
        remaining = remove(ALLCARDS, hand1)
        for hand2 in choose(remaining, 5)

            Showdown_Schnapsen!(s, hand1, hand2, HEARTS, 1)
            val, t1, t2 = showdown_alphabeta(s, -1000, 1000, 10, mls, uls)
            table[(hand1, hand2)] = t1, t2 # val = t1 - t2
        end
    end
    return table
end

table = gen_showdown_table()

import JLD2

JLD2.@save "showdowntable.jld2" table

#
# binomial(20, 5) * binomial(15, 5) * 0.0001 / 60
#
#
# hands1 = choose(all_cards(), 5)
#
# reduce(|, hands1[100], init=NOCARDS)
#
#
s = Showdown_Schnapsen!(Schnapsen())
#
using BenchmarkTools
mls = [MoveList() for _ in 1:20]
uls = [Undo() for _ in 1:20]
@btime showdown_alphabeta(s, -1_000, 1_000, 10, mls, uls) #26.800 μs (276 allocations: 21.56 KiB)

(binomial(20, 5) * binomial(15, 5)) * 30*10^-6 / 60
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
