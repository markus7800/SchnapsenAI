include("game2.jl")

@info "Benchmark Multithread:" Threads.nthreads()

g = Game(0)
play_move!(g, stringtomove("10♣ t")) # 10♣ t: 0.5784 1000 (AB: K♣ t 2000, 10♡ 2000)
play_move!(g, stringtomove("A♣")) # A♣: 0.672 1000 (A♣: 1000.0)

Random.seed!(0)
@time eval_moves_prob(g, 2500)

#julia --project=. --threads=1 benchmark_multithread.jl

# Q♣: 0.7428 ± 0.0087
# 10♠: 0.9048 ± 0.0059
# J♢: 0.7024 ± 0.0091 *
# Q♢: 0.7712 ± 0.0084
# A♡: 0.8744 ± 0.0066

# macbook
# n_threads, % CPU, User load, time
# 1, 99, 28%, 2:04
# 2, 160, 44%, 1:25
# 4, 250, 65%, 1:09
# 8, 300, 80%, 1:02

# macbook outer
# n_threads, % CPU, User load, time
# 1, 99, 28%, 2:07
# 2, 200, 53%, 1:07
# 4, 380, 98%, 0:58
