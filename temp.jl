
include("game2.jl")


@time best_AB_move(g)
@time eval_lock_moves(g)
@time eval_moves_full(g)

Random.seed!(0)
@time eval_moves_prob(g, 2500)

# @time eval_moves_prob(g, 2500) new game
# 13:42 -> 7:26 at 65 % load macbook
# 822.231530 seconds (1.72 M allocations: 87.468 MiB, 0.00% gc time, 0.05% compilation time)
# A♠ t: 0.8284
# K♣ t: 0.6560
# 10♣ t: 0.5792 *
#   J♠: 0.9224
# 10♢ t: 0.6580
# 10♡ t: 0.6628

# 2 moves deep: 2:05
# 4 moves deep 0:20 -> 12s

g = Game(0)
# 2500
eval_moves_prob(g, 2500) # 7min

play_move!(g, stringtomove("10♣ t")) # 10♣ t: 0.5784 1000 (AB: K♣ t 2000, 10♡ 2000)
eval_moves_prob(g, 2500) # 2min

play_move!(g, stringtomove("A♣")) # A♣: 0.672 1000 (A♣: 1000.0)
eval_moves_prob(g, 2500) # 1min

play_move!(g, stringtomove("J♢")) # J♢: 0.708 2000
eval_moves_prob(g, 2500) # 17s
eval_moves_prob(g, 10000) # 1min

play_move!(g, stringtomove("10♢")) # 10♢: 0.752 (10♢: 2000)
eval_moves_prob(g, 2500) # 10s
eval_moves_prob(g, 10000) # 40s
@time eval_moves_full(g) # 2min


s = Schnapsen("KC 10C JS 10D 10H", "AS")
g = Game(s)
eval_moves_prob(g, 2500)



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

r = estimate_ab_time_at_depth(100, 20)
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
