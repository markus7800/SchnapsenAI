include("schnapsen.jl")
include("alphabeta.jl")
using Printf

mutable struct Game
    s::Schnapsen
    played_cards::Cards
    last_atout::Card
    calls::Vector{Tuple{Card,Int}}
    atout_swap::Card
    atout_swap_player::Int
    perspective::Int
end

function Game(seed::Int, perspective::Int=0)
    s = Schnapsen(seed)
    return Game(s, perspective)
end

function Game(s::Schnapsen, perspective::Int=0)
    played_cards = NOCARDS
    return Game(s, played_cards, s.talon[1], [], NOCARD, 0, perspective)
end

function Base.show(io::IO, game::Game)
    println(io, "Schnapsen Game:")
    show_schnapsen(io, game.s, game.perspective)
    println(io, "\n", "-"^40)
    println(io, "Played cards: $(game.played_cards)")
    println(io, "last_atout $(game.last_atout)")
    print(io, "Calls: ")
    for call in game.calls
        print(io, call[1], "($(call[2]))")
    end
    println(io)
    println(io, "Atout swap: $(game.atout_swap) ($(game.atout_swap_player))")
    println(io, "Perspective: $(game.perspective)")
    println(io, "\n", "-"^40)
end

import Base:stdout
function print_game(game::Game)
    Base.show(stdout, game.s)
end

function play_move!(game::Game, m::Move)
    legal_moves = get_moves(game.s)
    @assert m in legal_moves "Illegal move $m : $legal_moves"
    game.played_cards = add(game.played_cards, m.card)
    if m.call
        spouse = face(m.card) == KING ? QUEEN : KING
        push!(game.calls, (Card(suit(m.card), spouse), game.s.player_to_move))
    end

    if m.swap
        game.atout_swap = game.s.talon[1] # before we make move
        game.atout_swap_player = game.s.player_to_move
    end

    make_move!(game.s, m, Undo())
    game.last_atout = game.s.talon[1]
    m
end


function play_move!(game::Game, m::String)
    play_move!(game, stringtomove(m))
end

include("game_from_string.jl")

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

    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    mask = [is_locked(s) || m.lock for m in movelist]
    movelist = MoveList(movelist[mask])
    if length(movelist) == 0
        return movelist, Float64[]
    end

    n_hands = binomial(length(candidate_cards), n_opponent_hand)
    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards = ", n_hands, " possible opponent hands.")


    u = Undo()
    ab = AlphaBeta(20)
    n_lost = zeros(Int, length(movelist))

    for (movenumber, move) in enumerate(movelist)
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

    losing_prob = losing_prob

    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        @printf("%6s: %.4f %s\n", move, losing_prob[movenumber], asterix)
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


    nthreads = Threads.nthreads()

    s_copies = [deepcopy(game.s) for _ in 1:nthreads]
    u_copies = [Undo() for _ in 1:nthreads]
    ab_copies = [AlphaBeta(20) for _ in 1:nthreads]

    movelist = MoveList()
    get_moves!(movelist, game.s)
    mask = [!m.lock for m in movelist]
    movelist = MoveList(movelist[mask])

    n_lost = zeros(Int, length(movelist), nthreads)

    opponent_hands = collect(choose(candidate_cards, n_opponent_hand))

    progressbar = ProgressMeter.Progress(length(opponent_hands) * length(movelist))

    for (movenumber, move) in enumerate(movelist)
        #count = 0
        Threads.@threads for i in 1:length(opponent_hands)
            tid = Threads.threadid()
            u = u_copies[tid]
            ab = ab_copies[tid]
            s = s_copies[tid]

            opphand = opponent_hands[i]
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
                #count += 1
                for j in 2:n_talon
                    s.talon[j] = p[j-1]
                end

                make_move!(s, move, u)
                score = go(ab, s)
                undo_move!(s, move, u)

                if s.player_to_move == 1
                    n_lost[movenumber, tid] += score < 0
                else
                    n_lost[movenumber, tid] += score > 0
                end
            end
            ProgressMeter.next!(progressbar)
            #println(opphand)
        end
        #@assert count == n_games
    end

    n_lost = vec(sum(n_lost, dims=2))

    losing_prob = n_lost ./ n_games
    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        @printf("%6s: %.4f %s\n", move, losing_prob[movenumber], asterix)
    end
    return movelist, losing_prob
end


# X_i ~ Bernoulli(p)
# ̂p = 1/N sum_{i=1}^N X_i ~ 1/N Binom(p, N)
# -> Var(̂p) = 1/N^2 N p(1-p) = p (1-p) / N < 1 / 4N


# Beta(1,1) = Unif(0,1) p-prior
# Bernoulli conjugate
# Beta(1 + ∑X_i, 1 + N - ∑ X_i) posterior
# var = α β / ((α + β)^2 (α + β + 1)) ≈ α β / N^3 ≈ p (1-p) / N < 1 / 4N

# -> std < 1 / 2√N
1 / (2 * sqrt(2500))

function get_freq_std(n_iter::Int, n_lost::Int)
    N = n_iter
    s = n_lost
    return sqrt(1/(N-1) * (s*(1-s/N)^2 + (N-s)*(s/N)^2))
end

function get_bayesian_std(n_iter::Int, n_lost::Int)
    N = n_iter
    s = n_lost
    α = 1 + s
    β = 1 + N - s
    return sqrt(α * β / ((α + β)^2 * (α + β + 1)))
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

    nthreads = Threads.nthreads()

    s_copies = [deepcopy(game.s) for _ in 1:nthreads]
    u_copies = [Undo() for _ in 1:nthreads]
    ab_copies = [AlphaBeta(20) for _ in 1:nthreads]

    movelist = MoveList()
    get_moves!(movelist, game.s)
    mask = [!m.lock for m in movelist]
    movelist = MoveList(movelist[mask])

    candidate_cards = collect(candidate_cards)
    sampled_cards_copies = [copy(candidate_cards) for _ in 1:nthreads]

    n_lost = zeros(Int, length(movelist), nthreads)
    progressbar = ProgressMeter.Progress(n_iter)
    Threads.@threads for iter in 1:n_iter
        tid = Threads.threadid()
        sampled_cards = sampled_cards_copies[tid]
        u = u_copies[tid]
        ab = ab_copies[tid]
        s = s_copies[tid]

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

        for movenumber in 1:length(movelist)
            move = movelist[movenumber]

            make_move!(s, move, u)
            score = go(ab, s)
            undo_move!(s, move, u)

            if s.player_to_move == 1
                n_lost[movenumber, tid] += score < 0
            else
                n_lost[movenumber, tid] += score > 0
            end
        end

        ProgressMeter.next!(progressbar)
    end

    n_lost = vec(sum(n_lost, dims=2))
    losing_prob = n_lost ./ n_iter

    min_losing_prob = minimum(losing_prob)
    for (movenumber, move) in enumerate(movelist)
        asterix = losing_prob[movenumber] ≈ min_losing_prob ? "*" : ""
        @printf("%6s: %.4f ± %.4f %s\n", move, losing_prob[movenumber], get_bayesian_std(n_iter, n_lost[movenumber]), asterix)
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
        asterix = scores[movenumber] == best_score ? "*" : ""
        @printf("%6s: %7.1f %s\n", move, scores[movenumber], asterix)
    end
    println("Best score: $best_score; player to move $(s.player_to_move)")
    return movelist, scores
end



function get_best_move(game::Game, lock_prob_threshold::Float64=0.25)
    lock_movelist, lock_losing_prob = eval_lock_moves(game)

    if length(lock_movelist) > 0 && (
            is_locked(game.s) ||
            (minimum(lock_losing_prob) < lock_prob_threshold && length(game.played_cards) ≤ 4)
        )
        # risk early lock without looking at other moves, otherwise always full search
        movelist, losing_prob = lock_movelist, lock_losing_prob
    else
        if length(game.played_cards) ≤ 2
            @info "Evaluate 2_500 random games (< 0.01 deviation)."
            movelist, losing_prob = eval_moves_prob(game, 2_500)
        elseif length(game.played_cards) == 3
            @info "Evaluate 10_000 random games (< 0.005 deviation)."
            movelist, losing_prob = eval_moves_prob(game, 10_000)
        else
            @info "Evaluate full."
            movelist, losing_prob = eval_moves_full(game)
        end
        movelist = vcat(vec(movelist), vec(lock_movelist))
        losing_prob = vcat(losing_prob, lock_losing_prob)
    end

    amin = argmin(losing_prob)
    move = movelist[amin]
    prob = losing_prob[amin]

    @info @sprintf("Best move: %s with losing probability %.4f", move, prob)

    return move, prob
end
