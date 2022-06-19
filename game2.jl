include("schnapsen.jl")
include("alphabeta.jl")

mutable struct Game
    s::Schnapsen
    played_cards::Cards
    last_atout::Card
    call::Card # TODO
    atout_swap::Card # TODO
end

function Game(seed::Int)
    s = Schnapsen(seed)
    played_cards = NOCARDS
    return Game(s, played_cards, s.talon[1], NOCARD, NOCARD)
end

function Base.show(io::IO, game::Game)
    show_schnapsen(io, game.s, game.s.player_to_move)
end

import Base:stdout
function print_game(game::Game, perspective=0)
    show_schnapsen(stdout, game.s, perspective)
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

function eval_lock_moves(game::Game)
    player_hand = game.s.player_to_move == 1 ? game.s.hand1 : game.s.hand2
    real_opponent_hand = game.s.player_to_move == 1 ? game.s.hand2 : game.s.hand1

    candidate_cards = remove(ALLCARDS, game.played_cards)
    candidate_cards = remove(candidate_cards, game.last_atout)
    candidate_cards = remove(candidate_cards, player_hand)

    n_hands = binomial(length(candidate_cards), length(real_opponent_hand))
    println(n_hands, " possible opponent hands.")

    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    for move in movelist
        !move.lock && continue
        n_loose = 0
        for (i, opphand) in enumerate(choose(candidate_cards, length(real_opponent_hand)))
            # println(opphand)
            if s.player_to_move == 1
                s.hand2 = opphand
            else
                s.hand1 = opphand
            end
            make_move!(s, move, u)
            score = go(ab, s)
            undo_move!(s, move, u)

            if s.player_to_move == 1
                n_loose += score < 0
            else
                n_loose += score > 0
            end
        end
        loosing_prob = n_loose / n_hands
        println("$(move): $(losing_prob)")
    end
end


g = Game(0)
@time eval_lock_moves(g)

moves = get_moves(g.s)

function number_of_possible_games(n_talon::Int)
    # opponent hand + order of talon
    binomial(n_talon + 5, 5) * factorial(n_talon)
end

function print_number_of_possible_games()
    for n in 9:-1:0
        println("$n: ", number_of_possible_games(n))
    end
end
