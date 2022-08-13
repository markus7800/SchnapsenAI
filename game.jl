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

function get_candidate_cards(game::Game; player=missing)
    if ismissing(player)
        player = game.s.player_to_move
    end

    player_hand = player == 1 ? game.s.hand1 : game.s.hand2
    real_opponent_hand = player == 1 ? game.s.hand2 : game.s.hand1

    candidate_cards = remove(ALLCARDS, game.played_cards)
    candidate_cards = remove(candidate_cards, game.last_atout)
    candidate_cards = remove(candidate_cards, player_hand)

    n_opponent_hand = length(real_opponent_hand)
    cards_add = NOCARDS
    if game.atout_swap != NOCARD && !(game.atout_swap in game.played_cards) && game.atout_swap_player != player
        candidate_cards = remove(candidate_cards, game.atout_swap)
        cards_add = add(cards_add, game.atout_swap)
        n_opponent_hand -= 1
    end
    for (callcard, player) in game.calls
        if !(callcard in game.played_cards) && player != player
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
        return movelist, Float64[], Float64[]
    end

    n_hands = binomial(length(candidate_cards), n_opponent_hand)
    println(length(candidate_cards), " unseen cards + ", n_opponent_hand, " unkown opponent cards = ", n_hands, " possible opponent hands.")


    u = Undo()
    ab = AlphaBeta(20)
    n_lost = zeros(Int, length(movelist))
    n_score = zeros(Int, length(movelist), 7)

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
                n_score[movenumber, score ÷ 1000 + 4] += 1 # score ÷ 1000 = -3,-2,-1,0,1,2,3
            else
                n_lost[movenumber] += score > 0
                n_score[movenumber, (-score) ÷ 1000 + 4] += 1
            end
        end
    end
    losing_prob = n_lost ./ n_hands
    expected_score = (n_score ./ n_hands) * [-3,-2,-1,0,1,2,3]

    min_losing_prob = minimum(losing_prob)
    max_score = maximum(expected_score)

    for (movenumber, move) in enumerate(movelist)
        asterix1 = min_losing_prob ≈ losing_prob[movenumber] ? "*" : " "
        asterix2 = max_score ≈ expected_score[movenumber] ? "*" : ""
        @printf("%6s: losing probability: %.4f, expected score: %7.4f %s%s\n",
            move, losing_prob[movenumber], expected_score[movenumber],
            asterix1, asterix2)
    end
    return movelist, losing_prob, expected_score
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
    n_score = zeros(Int, length(movelist), 7, nthreads)

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
                    n_score[movenumber, score ÷ 1000 + 4, tid] += 1 # score ÷ 1000 = -3,-2,-1,0,1,2,3
                else
                    n_lost[movenumber, tid] += score > 0
                    n_score[movenumber, (-score) ÷ 1000 + 4, tid] += 1
                end
            end
            ProgressMeter.next!(progressbar)
            #println(opphand)
        end
        #@assert count == n_games
    end

    n_lost = vec(sum(n_lost, dims=2))
    n_score = sum(n_score, dims=3)[:,:,1] # (n_moves, 7)

    losing_prob = n_lost ./ n_games
    expected_score = (n_score ./ n_games) * [-3,-2,-1,0,1,2,3]

    min_losing_prob = minimum(losing_prob)
    max_score = maximum(expected_score)

    for (movenumber, move) in enumerate(movelist)
        asterix1 = min_losing_prob ≈ losing_prob[movenumber] ? "*" : " "
        asterix2 = max_score ≈ expected_score[movenumber] ? "*" : ""
        @printf("%6s: losing probability: %.4f, expected score: %7.4f %s%s\n",
            move, losing_prob[movenumber], expected_score[movenumber],
            asterix1, asterix2)
    end
    avg_nodes = sum(ab.n_nodes for ab in ab_copies) / (length(opponent_hands) * length(movelist))
    @printf("Average of %.0f Nodes per game.\n", avg_nodes)
    return movelist, losing_prob, expected_score
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

# Dirichlet(1,1,1,1,1,1,1) = Unif([x: x ∈ R^7, sum x = 1]) prior over probability of scores -3,...,3
# Categorical(p1, ..., p7) conjugate
# Dirichlet(1 + c_1, ..., 1 + c_7) posterior c_i number of observations in category i
# P ∼ Dirichlet(α)
# expected_score = P ⋅ (-3,-2,-1,0,1,2,3) = P ⋅ S
# N + 7 = sum c_i + 7 = sum α_i
# p = α / (N + 7) < 1
# Cov(P_i, P_j) = ( δij p_i - p_i p_j ) / (N + 7 + 1)
# |Cov(P_i, P_j)| < 1/N
# var(expected_score) = sum_ij S_i S_j Cov(P_i, P_j) < 9 sum_ij Cov(P_i, P_j) < 9 * 7^2 / N

function get_freq_std(n_iter::Int, n_lost::Int)
    N = n_iter
    s = n_lost
    return sqrt(1/(N-1) * (s*(1-s/N)^2 + (N-s)*(s/N)^2))
end

import Distributions: Beta, Dirichlet, var, std, cov
function get_bayesian_losing_estimate(n_iter::Int, n_lost::Vector{Int})
    n = length(n_lost)
    losing_probs = zeros(n)
    losing_probs_std = zeros(n)

    N = n_iter

    for i in 1:n
        s = n_lost[i]
        α = 1 + s
        β = 1 + N - s
        b = Beta(α, β)
        losing_probs[i] = mean(b)
        losing_probs_std[i] = std(b)
    end

    return losing_probs, losing_probs_std
end

function get_bayesian_score_estimate(n_score::Array{Int, 2})
    n_moves, _ = size(n_score)
    S = [s1 * s2 for s1 in -3:3, s2 in -3:3]
    score_means = zeros(n_moves)
    score_stds = zeros(n_moves)
    for i in 1:n_moves
        d = Dirichlet(n_score[i, :] .+ 1)
        m = (-3:3)'mean(d)
        C = cov(d)
        v = sum(S .* C)
        score_means[i] = m
        score_stds[i] = sqrt(v)
    end
    return score_means, score_stds
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
    n_score = zeros(Int, length(movelist), 7, nthreads)
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
                n_score[movenumber, score ÷ 1000 + 4, tid] += 1 # score ÷ 1000 = -3,-2,-1,0,1,2,3
            else
                n_lost[movenumber, tid] += score > 0
                n_score[movenumber, (-score) ÷ 1000 + 4, tid] += 1
            end
        end

        ProgressMeter.next!(progressbar)
    end

    n_lost = vec(sum(n_lost, dims=2))
    n_score = sum(n_score, dims=3)[:,:,1] # (n_moves, 7)

    losing_prob, losing_probs_std = get_bayesian_losing_estimate(n_iter, n_lost)
    score_means, score_stds = get_bayesian_score_estimate(n_score)

    min_losing_prob = minimum(losing_prob)
    max_score = maximum(score_means)
    for (movenumber, move) in enumerate(movelist)
        asterix1 = min_losing_prob ≈ losing_prob[movenumber] ? "*" : " "
        asterix2 = max_score ≈ score_means[movenumber] ? "*" : ""

        @printf("%6s: losing probability %.4f ± %.4f, expected score %7.4f ± %.4f %s%s\n",
            move,
            losing_prob[movenumber], losing_probs_std[movenumber],
            score_means[movenumber], score_stds[movenumber],
            asterix1, asterix2)
    end

    avg_nodes = sum(ab.n_nodes for ab in ab_copies) / (n_iter * length(movelist))
    @printf("Average of %.0f Nodes per game.\n", avg_nodes)

    return movelist, losing_prob, score_means
end

function best_AB_move(game::Game)
    s = deepcopy(game.s)
    movelist = MoveList()
    get_moves!(movelist, s)
    u = Undo()
    ab = AlphaBeta(20)
    scores = zeros(Int, length(movelist))
    best_score = go(ab, s)
    for (movenumber, move) in enumerate(movelist)
        make_move!(s, move, u)
        score = go(ab, s)
        undo_move!(s, move, u)
        scores[movenumber] = score
    end

    if game.perspective == 1
        best = argmax(scores)
    else
        best = argmin(scores)
    end
    for (movenumber, move) in enumerate(movelist)
        asterix = scores[movenumber] == best_score ? "*" : ""
        @printf("%6s: %7.1f %s\n", move, scores[movenumber], asterix)
    end
    println("Best score: $best_score; player to move $(s.player_to_move)")
    return movelist[best], scores[best]
end



function get_best_move(game::Game, lock_prob_threshold::Float64=0.25)
    lock_movelist, lock_losing_prob, lock_expected_score = eval_lock_moves(game)

    if length(lock_movelist) > 0 && (
            is_locked(game.s) ||
            (minimum(lock_losing_prob) < lock_prob_threshold && length(game.played_cards) ≤ 4)
        )
        # risk early lock without looking at other moves, otherwise always full search
        movelist, losing_prob, expected_score = lock_movelist, lock_losing_prob, lock_expected_score
    else
        if length(game.played_cards) ≤ 2
            @info "Evaluate 2_500 random games (< 0.01 deviation)."
            movelist, losing_prob, expected_score = eval_moves_prob(game, 2_500)
        elseif length(game.played_cards) == 3
            @info "Evaluate 10_000 random games (< 0.005 deviation)."
            movelist, losing_prob, expected_score = eval_moves_prob(game, 10_000)
        else
            @info "Evaluate full."
            movelist, losing_prob, expected_score = eval_moves_full(game)
        end
        movelist = vcat(vec(movelist), vec(lock_movelist))
        losing_prob = vcat(losing_prob, lock_losing_prob)
        expected_score = vcat(expected_score, lock_expected_score)
    end

    amin = argmin(losing_prob)
    move = movelist[amin]
    prob = losing_prob[amin]
    score = expected_score[amin]

    return move, prob, score
end
