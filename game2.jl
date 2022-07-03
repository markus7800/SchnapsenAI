include("schnapsen.jl")
include("alphabeta.jl")

mutable struct Game
    s::Schnapsen
    played_cards::Cards
    last_atout::Card
    calls::Vector{Tuple{Card,Int}}
    atout_swap::Card
    atout_swap_player::Int
end

function Game(seed::Int)
    s = Schnapsen(seed)
    played_cards = NOCARDS
    return Game(s, played_cards, s.talon[1], [], NOCARD, 0)
end

function Base.show(io::IO, game::Game)
    println(io, "Schnapsen Game:")
    show_schnapsen(io, game.s, game.s.player_to_move)
    println(io, "\n", "-"^40)
    println(io, "Played cards: $(game.played_cards)")
    println(io, "last_atout $(game.last_atout)")
    print(io, "Calls: ")
    for call in game.calls
        print(io, call[1], "($(call[2]))")
    end
    println(io)
    println(io, "atout_swap $(game.atout_swap) ($(game.atout_swap_player))")
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
        push!(game.calls, (Card(suit(m.card), spouse), m.player_to_move))
    end

    if m.swap
        game.atout_swap = game.s.talon[1] # before we make move
        game.atout_swap_player = game.s.player_to_move
    end

    u = Undo()
    make_move!(game.s, m, u)
    game.last_atout = game.s.talon[1]

    m
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
    if game.atout_swap != NOCARD && !(game.atout_swap in game.played_cards) && game.atout_swap_player != game.s.player_to_move
        candidate_cards = remove(candidate_cards, game.atout_swap)
        cards_add = add(cards_add, game.atout_swap)
        n_opponent_hand -= 1
    end
    for (callcard, player) in game.calls
        if !(callcard in game.played_cards) && player != game.s.player_to_move
            candidate_cards = remove(candidate_cards, callcard)
            cards_add = add(cards_add, callcard)
            n_opponent_hand -= 1
        end
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
    n_lost = zeros(Int, length(movelist))

    for (movenumber, move) in enumerate(movelist)
        !is_locked(s) && !move.lock && continue
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
                n_lost[movenumber] += score < 0
            else
                n_lost[movenumber] += score > 0
            end
        end
    end
    losing_prob = n_lost ./ n_hands
    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        !is_locked(s) && !move.lock && continue
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        println("$(move):\t$(losing_prob[movenumber]) $asterix")
    end
    return movelist, losing_prob
end

import ProgressMeter
using Combinatorics
function eval_moves_full(game::Game)
    if is_locked(game.s)
        return eval_lock_moves(game)
    end

    candidate_cards, n_opponent_hand, cards_add = get_candidate_cards(game)

    n_talon = game.s.n_talon
    if n_talon > 0
        n_games = binomial(length(candidate_cards), n_opponent_hand) * factorial(n_talon-1)
    else
        n_games = binomial(length(candidate_cards), n_opponent_hand)
    end

    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards = ", binomial(length(candidate_cards), n_opponent_hand), " possible opponent hands.")
    println(" + ", n_talon, " talon cards = ", n_games, " games")


    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    remaining_cards = NOCARDS
    n_lost = zeros(Int, length(movelist))

    n_lost = zeros(length(movelist))
    for (movenumber, move) in enumerate(movelist)
        count = 0
        ProgressMeter.@showprogress "Move: $move" for (i, opphand) in enumerate(choose(candidate_cards, n_opponent_hand))
            opphand = add(opphand, cards_add)

            if s.player_to_move == 1
                s.hand2 = opphand
            else
                s.hand1 = opphand
            end

            n_talon == 0 && continue

            remaining_cards = remove(candidate_cards, opphand)
            @assert length(remaining_cards) == n_talon-1
            #println(remaining_cards, collect(remaining_cards), length(permutations(collect(remaining_cards))))
            for p in permutations(collect(remaining_cards))
                count += 1
                for j in 2:n_talon
                    s.talon[j] = p[j-1]
                end

                make_move!(s, move, u)
                score = go(ab, s)
                undo_move!(s, move, u)

                if s.player_to_move == 1
                    n_lost[movenumber] += score < 0
                else
                    n_lost[movenumber] += score > 0
                end
            end

            #println(opphand)
        end
        @assert count == n_games
    end
    losing_prob = n_lost ./ n_games
    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        println("$(move):\t$(losing_prob[movenumber]) $asterix")
    end
    return movelist, losing_prob
end

function eval_moves_prob(game::Game, n_iter::Int)
    if is_locked(game.s)
        return eval_lock_moves(game)
    end

    candidate_cards, n_opponent_hand, cards_add = get_candidate_cards(game)

    n_talon = game.s.n_talon
    if n_talon > 0
        n_games = binomial(length(candidate_cards), n_opponent_hand) * factorial(n_talon-1)
    else
        n_games = binomial(length(candidate_cards), n_opponent_hand)
    end

    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards = ", binomial(length(candidate_cards), n_opponent_hand), " possible opponent hands.")
    println(" + ", n_talon, " talon cards = ", n_games, " games")


    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    candidate_cards = collect(candidate_cards)
    sampled_cards = copy(candidate_cards)

    n_lost = zeros(Int, length(movelist))

    ProgressMeter.@showprogress for iter in 1:n_iter
        sample!(candidate_cards, sampled_cards, replace=false)
        opphand = cards_add
        i = 1
        for _ in 1:n_opponent_hand
            opphand = add(opphand, sampled_cards[i])
            i += 1
        end
        if s.player_to_move == 1
            s.hand2 = opphand
        else
            s.hand1 = opphand
        end
        for j in 2:n_talon
            s.talon[j] = sampled_cards[i]
            i += 1
        end

        for (movenumber, move) in enumerate(movelist)
            move.lock && continue
            make_move!(s, move, u)
            score = go(ab, s)
            undo_move!(s, move, u)

            if s.player_to_move == 1
                n_lost[movenumber] += score < 0
            else
                n_lost[movenumber] += score > 0
            end
        end
    end

    losing_prob = n_lost ./ n_iter
    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        move.lock && continue
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        println("$(move):\t$(losing_prob[movenumber]) $asterix")
    end
    return movelist, losing_prob
end

function best_AB_move(game::Game)
    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    scores = zeros(length(movelist))
    best_score = go(ab, s)
    for (movenumber, move) in enumerate(movelist)
        make_move!(s, move, u)
        score = go(ab, s)
        undo_move!(s, move, u)
        scores[movenumber] = score
    end

    for (movenumber, move) in enumerate(movelist)
        move.lock && continue
        asterix = scores[movenumber] == best_score ? "*" : ""
        println("$(move):\t$(scores[movenumber]) $asterix")
    end
    println("Best score: $best_score; player to move $(s.player_to_move)")
    return movelist, scores
end

@time best_AB_move(g)
@time eval_lock_moves(g)
@time eval_moves_full(g)
@time eval_moves_prob(g, 2500)

g = Game(0)
# 2500
play_move!(g, stringtomove("10♣ t")) # 10♣ t: 0.5784 1000 (AB: K♣ t 2000, 10♡ 2000)
play_move!(g, stringtomove("A♣")) # A♣: 0.672 1000 (A♣: 1000.0)

play_move!(g, stringtomove("J♢")) # J♢: 0.708 2000
play_move!(g, stringtomove("10♢")) # 10♢: 0.752 (10♢: 2000)

# full

@time eval_lock_moves(g)
@time eval_moves_full(g)
@time eval_moves_prob(g, 2500)

g = Game(0)
play_move!(g, stringtomove("AS t"))
play_move!(g, stringtomove("JD"))

play_move!(g, stringtomove("AH"))
play_move!(g, stringtomove("10S"))
# 10 unseen cards + 5 unkown opponent cards = 252 possible opponent hands.
# Q♣ z: 0.7380952380952381
# A♣ z: 0.1865079365079365
# K♠ z: 0.01984126984126984
# Q♢ z: 0.9523809523809523
# Q♢ az: 0.25
# K♢ z: 0.9523809523809523
# K♢ az: 0.25
#   0.056406 seconds (11.16 k allocations: 1008.625 KiB)
# 10 unseen cards + 5 unkown opponent cards = 252 possible opponent hands.
#  + 6 talon cards = 30240 games
# Q♣: 0.2769179894179894 30240
# Q♣ z: 0.7380952380952381 30240
# A♣: 0.373015873015873 30240
# A♣ z: 0.1865079365079365 30240
# K♠: 0.27781084656084654 30240
# K♠ z: 0.01984126984126984 30240
# Q♢: 0.3146494708994709 30240
# Q♢ z: 0.9523809523809523 30240
# Q♢ a: 0.1177579365079365 30240
# Q♢ az: 0.25 30240
# K♢: 0.31421957671957673 30240
# K♢ z: 0.9523809523809523 30240
# K♢ a: 0.1177579365079365 30240
# K♢ az: 0.25 30240
# 247.242452 seconds (4.41 M allocations: 192.565 MiB, 0.01% gc time)

play_move!(g, stringtomove("AC"))
play_move!(g, stringtomove("QH"))

ab = AlphaBeta(20)
@btime begin
    ab.n_nodes = 0
    go(ab, g.s)
end


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

begin
    s = zeros(Threads.nthreads())
    Threads.@threads for i in 1:1000
        s[Threads.threadid()] += 1
    end
    sum(s)
end
