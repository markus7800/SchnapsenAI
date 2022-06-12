include("schnapsen.jl")
include("alphabeta.jl")
include("game.jl")


using BenchmarkTools
@btime choose(ALLCARDS, 10)

cards = all_cards()[7:end]

using Combinatorics

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

cards = all_cards()[7:end]
length(combinations(cards, 5))

(number_of_possible_games(5) * 0.050) / 60 / 60 / 24

1 / 0.050
