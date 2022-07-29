include("game2.jl")

@info "Benchmark Multithread:" Threads.nthreads()


function Schnapsen(hand1::String, hand2::String, talon::String)
    sts = Dict(
        'S'=>SPADES, 'H'=>HEARTS, 'D'=>DIAMONDS, 'C'=>CLUBS,
        '♠'=>SPADES, '♡'=>HEARTS, '♢'=>DIAMONDS, '♣'=>CLUBS
        )
    fs = Dict("J"=>JACK, "Q"=>QUEEN, "K"=>KING, "10"=>TEN, "A"=>ACE)

    function parse(str)
        sgroups = split(str, " ")

        f = sgroups[1][1:end-1]
        st = sgroups[1][end]

        card = Card(sts[st], fs[f])
        return card
    end

    h1 = NOCARDS
    for c_str in split(hand1, " ")
        card = parse(c_str)
        #println(c_str, ": ", card)
        h1 = add(h1, card)
    end

    h2 = NOCARDS
    for c_str in split(hand2, " ")
        card = parse(c_str)
        #println(c_str, ": ", card)
        h2 = add(h2, card)
    end

    t = Vector{Card}()
    for c_str in split(talon, " ")
        card = parse(c_str)
        # println(c_str, ": ", card)
        push!(t, card)
    end

    s = Schnapsen()
    s.hand1 = h1
    s.hand2 = h2
    s.talon = t
    return s
end

s = Schnapsen("KC 10C JS 10D 10H", "QC AC 10S JD QD", "AS JH JC AD KH QS QH KS KD AH")
g = Game(s)

play_move!(g, stringtomove("10♣ t")) # 10♣ t: 0.5784 1000 (AB: K♣ t 2000, 10♡ 2000)
play_move!(g, stringtomove("A♣")) # A♣: 0.672 1000 (A♣: 1000.0)

Random.seed!(0)
@time eval_moves_prob(g, 2500)

# julia --project=. --threads=1 benchmark_multithread.jl

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

# intel xeon w-2255 @3.7ghz 10 cores 20 threads
# n_threads, CPU load, time
# 1
