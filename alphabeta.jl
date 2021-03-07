

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

gen_showdown_table()

binomial(20, 5) * binomial(15, 5) * 0.0001 / 60


hands1 = choose(all_cards(), 5)

reduce(|, hands1[100], init=NOCARDS)


s = Showdown_Schnapsen()

@btime showdown_alphabeta(s, -1000, 1000, 10)

s = Showdown_Schnapsen()

showdown_alphabeta(s, -1000, 1000, 2)
showdown_alphabeta(s, -1000, 1000, 4)
showdown_alphabeta(s, -1000, 1000, 6)
showdown_alphabeta(s, -1000, 1000, 8)
showdown_alphabeta(s, -1000, 1000, 10)

binomial(20, 5) * binomial(15, 5) * 5 / 1024^2
