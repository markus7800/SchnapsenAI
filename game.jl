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
    if n ≤ 5 || is_locked(g.s)
        # deterministic
    else
        # probalisitic
    end
end

function determinitic_best_move(g::Game, depth::Int)
    rootmoves = get_moves(s)
    values = [Int[] for m in rootmoves]

    hand = player == 1 ? g.s.hand1 : g.s.hand2
    cards = all_cards()
    cards = setdiff(cards, g.played_cards)
    cards = setdiff(cards, collect(hand))
    cards = setdiff(cards, g.last_atout)

    _cards = copy(cards)
    n = 0
    m = 0
    for opphand in combinations(cards, 5)

        talon_cards = setdiff(_cards, hand)

        hand1 = player == 1 ? hand : opphand
        hand2 = player == 2 ? hand : opphand

        for talon in permutations(talon_cards)
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
                val = alphabeta(s,-10_000, 10_000, depth-1)
                push!(values, val)
                undo_move!(s, move, u)
            end


            n += 1
        end
        m += 1
        println(m, ": ", n)
    end



    return collect(zip(rootmoves, values))
end

function number_of_possible_games(n_talon::Int)
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
