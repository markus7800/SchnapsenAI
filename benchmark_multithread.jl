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

#play_move!(g, stringtomove("10♣ t")) # 10♣ t: 0.5784 1000 (AB: K♣ t 2000, 10♡ 2000)
#play_move!(g, stringtomove("A♣")) # A♣: 0.672 1000 (A♣: 1000.0)

Random.seed!(0)
@time eval_moves_prob(g, 2500)

# julia --project=. --threads=1 benchmark_multithread.jl

# macbook 2,3 GHz Dual-Core Intel Core i5 4 threads
# n_threads, % CPU, User load, time

# two moves in
# 1, 99, 28%, 2:07
# 2, 200, 53%, 1:07
# 4, 380, 98%, 0:58

# from beginning
# 1, 13:42
# 4, 6:19

# intel xeon w-2255 @3.7ghz 10 cores 20 threads
# n_threads, CPU load, time

# two moves in
# 1, 10%, 1:43
# 10, 62%, 0:23
# 20, 100%, 0:26

# from beginning
# 1, 10%, 11:26
# 10, 70%, 2:46
# 20, 100% 1:34
