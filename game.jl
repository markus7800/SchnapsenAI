include("alphabeta.jl")

mutable struct Game
    s::Schnapsen
    played_cards::Cards
    last_atout::Card
end

function Game(seed::Int)
    s = Schnapsen(seed)
    played_cards = NOCARDS
    return Game(s, played_cards, s.talon[1])
end

function Base.show(io::IO, game::Game)
    show_schnapsen(io, game.s, game.s.player_to_move)
end

# 4 μs
function get_random_candidate_schnapsen(g::Game)
    player = g.s.player_to_move
    cards = ALLCARDS
    cards = Cards(cards.cs & ~g.played_cards.cs)
    cards = Cards(cards.cs & ~g.last_atout.c)

    hand = player == 1 ? g.s.hand1 : g.s.hand2
    cards = Cards(cards.cs & ~hand.cs)

    cards = collect(cards)
    opphand = sample(cards, 5, replace=false)
    opphand = reduce(|, opphand, init=NOCARDS)

    talon = setdiff!(cards, opphand)
    talon = sample(talon, length(talon), replace=false)
    pushfirst!(talon, g.last_atout)

    hand1 = player == 1 ? hand : opphand
    hand2 = player == 2 ? hand : opphand

    s = Schnapsen(talon, g.s.atout, hand1, hand2,
        g.s.played_card,
        g.s.lock,
        g.s.stichlos,

        g.s.trickscore1,
        g.s.trickscore2,
        g.s.lasttrick,

        g.s.call1,
        g.s.call2,

        g.s.player_to_move)

    return s
end


function best_move(g::Game)
    n = length(g.s.talon) - 1 # unkown talon
    rootmoves = get_moves(g.s)
    local res
    if is_locked(g.s) || n ≤ 5
        res = determinitic_best_move(g, rootmoves)
        analyze(rootmoves, res)
    else
        # [(10^5, 2), (10^5, 2)]
        res = probabilistic_best_move(g, rootmoves, 10^5, 2)
        analyze(rootmoves, res)
    end
end

function freq_table(A::Vector)
    count_dict = Dict()
    for a in A
        c = get(count_dict, a, 0)
        count_dict[a] = c + 1
    end

    count_dict
end

using Printf
using Statistics
function analyze(rootmoves, values)
    for (rootmove, value) in zip(rootmoves, values)
        if value isa Vector
            terminal_games = value[abs.(value) .> 100]
            terminal_perc = length(terminal_games) / length(value) * 100
            other_games = value[abs.(value) .≤ 100]
            other_perc = length(other_games) / length(value) * 100

            score_mean = mean(other_games)
            score_std = std(other_games)

            terminal_mean = mean(terminal_games)
            terminal_std = std(terminal_games)

            table = freq_table(terminal_games)

            println(@sprintf "%s: %d unfinished games (%.2f%%) score: %.2f ± %.2f" rootmove length(other_games) other_perc score_mean score_std)
            println(@sprintf "\t\t%d terminal games (%.2f%%) score: %.2f ± %.2f outcomes: %s" terminal_perc length(terminal_games) terminal_mean terminal_std table)
        end
    end
end


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

function showdown_bestmove(s::Schnapsen)
    rootmoves = get_moves(s)
    values = Int[]
    for m in rootmoves
        u = make_move!(s, m)
        val = alphabeta(s,-10_000, 10_000, 20)
        push!(values, val)
        undo_move!(s, m, u)
    end

    return collect(zip(rootmoves, values))
end

function determinitic_best_move(g::Game, rootmoves::Vector{Move})
    player = g.s.player_to_move
    hand = player == 1 ? g.s.hand1 : g.s.hand2
    cards = all_cards()
    cards = setdiff(cards, g.played_cards)
    cards = setdiff(cards, collect(hand))
    cards = setdiff(cards, [g.last_atout])

    _cards = copy(cards)

    n_games = binomial(length(cards), 5) * factorial(length(cards)-5)
    values = [Vector{Int}(undef, n_games) for move in rootmoves]


    for (m, opphand) in enumerate(combinations(cards, 5))
        opphand = reduce(|, opphand, init=NOCARDS)

        talon_cards = setdiff(_cards, opphand)

        hand1 = player == 1 ? hand : opphand
        hand2 = player == 2 ? hand : opphand

        for (n, talon) in enumerate(permutations(talon_cards))

            pushfirst!(talon, g.last_atout)

            s = Schnapsen(talon, g.s.atout, hand1, hand2,
                g.s.played_card,
                g.s.lock,
                g.s.stichlos,

                g.s.trickscore1,
                g.s.trickscore2,
                g.s.lasttrick,

                g.s.call1,
                g.s.call2,

                g.s.player_to_move)

            for (i, move) in enumerate(rootmoves)
                u = make_move!(s, move)
                values[i][n] = alphabeta(s,-10_000, 10_000, 20)
                undo_move!(s, move, u)
            end
        end

        print("$m: $n")
    end

    return values
end

function probabilistic_best_move(g::Game, rootmoves::Vector{Move}, n_iter::Int, depth::Int)
    values = [Vector{Int}(undef, n_iter) for move in rootmoves]

    for n in 1:n_iter
        s = get_random_candidate_schnapsen(g)

        for (i, move) in enumerate(rootmoves)
            u = make_move!(s, move)
            values[i][n] = alphabeta(s,-10_000, 10_000, depth-1)
            undo_move!(s, move, u)
        end
    end

    return values
end

function number_of_possible_games(n_talon::Int)
    # opponent hand + order of talon
    binomial(n_talon + 5, 5) * factorial(n_talon)
end

function print_number_of_possible_games()
    for n in 9:-1:0
        println("$n: ", number_of_possible_games(n))
    end
end

# function choose(set::Cards, k::Int)
#     n = count_ones(set.cs)
#     if n == 0 && k > 0
#         return Vector{Cards}()
#     end
#     if k == 0
#         return [NOCARDS]
#     end
#     s = first(set)
#     set = removefirst(set)
#
#     A = choose(set, k) # exclude s
#     B = map(newset -> add(newset, s), choose(set, k-1)) # include s
#
#     return append!(A, B)
# end

using BenchmarkTools
@btime choose(ALLCARDS, 10)

cards = all_cards()[7:end]

permutations()

@btime collect(combinations(all_cards(), 10))

@time begin
    cards = all_cards()[7:end]
    _cards = copy(cards)
    n = 0
    m = 0
    for hand in combinations(cards, 5)
        # println(hand)
        talon_cards = setdiff(_cards, hand)
        for talon in permutations(talon_cards)
            n += 1
        end
        m += 1
        println(m, ": ", n)
    end
    n
end
