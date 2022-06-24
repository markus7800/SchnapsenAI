include("schnapsen.jl")
include("alphabeta.jl")

mutable struct Game
    s::Schnapsen
    played_cards::Cards
    last_atout::Card
    call::Card
    atout_swap::Card
end

function Game(seed::Int)
    s = Schnapsen(seed)
    played_cards = NOCARDS
    return Game(s, played_cards, s.talon[1], NOCARD, NOCARD)
end

function Base.show(io::IO, game::Game)
    println(io, "Schnapsen Game:")
    show_schnapsen(io, game.s, game.s.player_to_move)
    println(io, "\nPlayed cards: $(game.played_cards), last_atout $(game.last_atout), call: $(game.call), atout_swap $(game.atout_swap).")
end

import Base:stdout
function print_game(game::Game, perspective=0)
    Base.show(stdout, game.s, perspective)
end

function play_move!(game::Game, m::Move)
    legal_moves = get_moves(game.s)
    @assert m in legal_moves "Illegal move $m : $legal_moves"
    game.played_cards = add(game.played_cards, m.card)
    if m.call
        spouse = face(m.card) == KING ? QUEEN : KING
        game.call = Card(suit(m.card), spouse)
    end

    if m.swap
        game.atout_swap = game.s.talon[1] # before we make move
    end

    u = Undo()
    make_move!(game.s, m, u)
    game.last_atout = game.s.talon[1]
end


function play_move!(game::Game, m::String)
    play_move!(game, stringtomove(m))
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

function get_candidate_cards(game::Game)
    player_hand = game.s.player_to_move == 1 ? game.s.hand1 : game.s.hand2
    real_opponent_hand = game.s.player_to_move == 1 ? game.s.hand2 : game.s.hand1

    candidate_cards = remove(ALLCARDS, game.played_cards)
    candidate_cards = remove(candidate_cards, game.last_atout)
    candidate_cards = remove(candidate_cards, player_hand)

    n_opponent_hand = length(real_opponent_hand)
    cards_add = NOCARDS
    if game.atout_swap != NOCARD && !(game.atout_swap in game.played_cards)
        candidate_cards = remove(candidate_cards, game.atout_swap)
        cards_add = add(cards_add, game.atout_swap)
        n_opponent_hand -= 1
    end
    if game.call != NOCARD && !(game.call in game.played_cards)
        candidate_cards = remove(candidate_cards, game.call)
        cards_add = add(cards_add, game.call)
        n_opponent_hand -= 1
    end

    return candidate_cards, n_opponent_hand, cards_add
end

function eval_lock_moves(game::Game)
    candidate_cards, n_opponent_hand, cards_add = get_candidate_cards(game)

    n_hands = binomial(length(candidate_cards), n_opponent_hand)
    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards = ", n_hands, " possible opponent hands.")

    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    for move in movelist
        !is_locked(s) && !move.lock && continue
        n_loose = 0
        for (i, opphand) in enumerate(choose(candidate_cards, n_opponent_hand))
            opphand = add(opphand, cards_add)

            #println(opphand)
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
        losing_prob = n_loose / n_hands
        println("$(move): $(losing_prob)")
    end
end

function eval_moves_full(game::Game)
    if is_locked(game.s)
        return eval_lock_moves(game)
    end

    candidate_cards, n_opponent_hand, cards_add = get_candidate_cards(game)

    n_talon = game.s.n_talon
    if n_talon > 0
        n_hands = binomial(length(candidate_cards), n_opponent_hand) * factorial(n_talon-1)
    else
        n_hands = binomial(length(candidate_cards), n_opponent_hand)
    end

    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards + ", n_talon, " talon cards = ", n_hands, " possible opponent hands.")
end


g = Game(0)
play_move!(g, stringtomove("AS t"))
play_move!(g, stringtomove("JD"))


play_move!(g, stringtomove("AH"))
play_move!(g, stringtomove("10S"))

@time eval_lock_moves(g)
@time eval_moves_full(g)

moves = get_moves(g.s)

function number_of_possible_games(n_talon::Int)
    # opponent hand + order of talon
    binomial(n_talon-1 + 5, 5) * factorial(n_talon-1)
end

function number_of_possible_games(n_talon::Int, depth::Int)
    # opponent hand + choice of next "depth" talon cards + order of them
    binomial(n_talon-1 + 5, 5) * binomial(n_talon-1, depth) * factorial(depth)
end

function print_number_of_possible_games()
    for n in 10:-1:^0
        println("$n: ", number_of_possible_games(n))
    end
end

import ProgressMeter
function estimate_ab_time_at_depth(n_iter, depth)
    times = zeros(20)
    counts = zeros(Int, 20)

    ab = AlphaBeta(depth)
    movelist = MoveList()
    u = Undo()
    ProgressMeter.@showprogress for seed in 1:n_iter
        s = Schnapsen(seed)
        d = 20
        while !is_gameover(s)
            stats = @timed go(ab, s) # time in seconds
            #println(d, ":, ", stats.time)
            times[d] += stats.time
            counts[d] += 1

            recycle!(movelist)
            get_moves!(movelist, s)
            m = rand(movelist)
            make_move!(s, m, u)
            d -= 1
        end
    end

    return times ./ counts
end

ms = get_moves(Schnapsen())

r = estimate_ab_time_at_depth(10000, 4)
n_games = [number_of_possible_games(max(d-10, 1)) for d in 1:20]

using Printf
for d in 12:20
    perc = 10/r[d]/n_games[d]*100
    perc = perc > 100 ? 100 : perc
    @printf "Depth: %2d, Talon %1d Number of games %10d, ab time %.6fs, search all %10.2fs, %10.0f in 10s (%.2f%%)\n" d d-10 n_games[d] r[d] n_games[d]*r[d] 10/r[d] perc
end

# Depth 12-15 (Talon 2-5) full search possible
# Depth 16: Full 37s Or 27% in 10s, d=10 12s or 83%
# Depth 17: Full 1%, d=10 6%, d=4 8.82s
# Depth 18: d=4 8% 350000
# Depth 19: d=4 0.4% 200000
# Depth 20: d=4 0.02% 150000
r .* n_games

10 ./ r
