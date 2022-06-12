
include("cards.jl")


mutable struct Schnapsen
    talon::Vector{Card} # atoutcard is talon[0]
    n_talon::Int
    atout::Cards

    hand1::Cards
    hand2::Cards

    played_card::Card
    lock::Int
    stichlos::Bool

    trickscore1::Int
    trickscore2::Int
    lasttrick::Int

    call1::Int
    call2::Int

    player_to_move::Int
end

import Base.==
function ==(l::Schnapsen, r::Schnapsen)
    if l.n_talon != r.n_talon
        return false
    end
    if length(l.talon) != length(r.talon)
        return false
    end
    for (lc, rc) in zip(l.talon, r.talon)
        if lc != rc
            return false
        end
    end

    if l.atout != r.atout
        return false
    end
    if l.hand1 != r.hand1 || l.hand2 != r.hand2
        return false
    end
    if l.played_card != r.played_card || l.lock != r.lock || l.stichlos != r.stichlos
        return false
    end
    if l.trickscore1 != r.trickscore1 || l.trickscore2 != r.trickscore2
        return false
    end
    if l.lasttrick != r.lasttrick
        return false
    end
    if l.call1 != r.call1 || l.call2 != r.call2
        return false
    end
    if l.player_to_move != r.player_to_move
        return false
    end

    return true
end

function isatout(s::Schnapsen, card::Card)
    (s.atout.cs & card.c) != 0
end



using StatsBase
using Random
function Schnapsen(seed=0)
    Random.seed!(seed)
    cards = sample(all_cards(), 20, replace=false)

    hand1 = NOCARDS
    hand2 = NOCARDS
    for i in 1:5
        c1 = pop!(cards)
        c2 = pop!(cards)
        hand1 = add(hand1, c1)
        hand2 = add(hand2, c2)
    end

    atoutcard = cards[1]
    atout = suit(atoutcard)
    atoutjack = Card(atout, JACK)
    if atoutjack in hand1
        hand1 = remove(hand1, atoutjack)
        hand1 = add(hand1, atoutcard)
        cards[1] = atoutjack
    end
    if atoutjack in hand2
        hand2 = remove(hand2, atoutjack)
        hand2 = add(hand2, atoutcard)
        cards[1] = atoutjack
    end

    Schnapsen(
        cards,
        10,
        atout,

        hand1,
        hand2,

        NOCARD, # played_card
        0, # lock
        false, # stichlos

        # trickscores
        0,
        0,
        0, # lasttrick

        # call
        0,
        0,

        1 # player_to_move
    )
end


function Base.show(io::IO, s::Schnapsen)
    show_schnapsen(io, s, s.player_to_move)
end

function show_schnapsen(io::IO, s::Schnapsen, perspective=0)
    print(io, "Player 2: ")
    if perspective != 1
        for card in s.hand2
            print(io, card, " ")
        end
        println(io, ", $(s.trickscore2) (+ $(s.call2))")
    else
        println(io, "* * * * *")
    end

    println(io, "Played: $(s.played_card)")

    if perspective == 0
        print(io, "Talon: ")
        for card in s.talon[1:s.n_talon]
            print(io, card, " ")
        end
        println(io)
    end

    print(io, "atout: $(SUIT_SYMBOLS[s.atout]), ")
    if is_locked(s)
        println(io, "locked by $(s.lock).")
    else
        println(io, "not locked.")
    end


    print(io, "Player 1: ")
    if perspective != 2
        for card in s.hand1
            print(io, card, " ")
        end
        println(io, ", $(s.trickscore1) (+ $(s.call1))")
    else
        println(io, "* * * * *")
    end

    println(io, "Last trick: $(s.lasttrick)")

    print(io, "Next Player: $(s.player_to_move)")
end

import Base:stdout
function print_schnapsen(s::Schnapsen, perspective=0)
    show_schnapsen(stdout, s, perspective)
end

function is_locked(s::Schnapsen)
    s.lock != 0
end

function playerscore(s::Schnapsen, player::Int)
    trickscore = player == 1 ? s.trickscore1 : s.trickscore2
    call = player == 1 ? s.call1 : s.call2

    score = trickscore

    if score > 0
        score += call
    end

    return score
end

function is_gameover(s::Schnapsen)
    if s.played_card != NOCARD
        return false
    end

    score1 = playerscore(s, 1)
    score2 = playerscore(s, 2)

    if score1 ≥ 66 || score2 ≥ 66
        return true
    end

    if length(s.hand1) + length(s.hand2) == 0
        return true
    end

    return false
end

function winner(s::Schnapsen)
    score1 = playerscore(s, 1)
    score2 = playerscore(s, 2)

    if score1 ≥ 66
        return 1
    end
    if score2 ≥ 66
        return 2
    end

    if score1 < 66 && s.lock == 1
        return 2
    end
    if score2 < 66 && s.lock == 2
        return 1
    end

    if score1 < 66 && score2 < 66
        return s.lasttrick
    end

    return 0
end

function winscore(s::Schnapsen)
    w = winner(s)
    l = w == 1 ? 2 : 1
    wscore = playerscore(s, w)
    lscore = playerscore(s, l)

    if wscore ≥ 66
        if lscore == 0
            return 3
        elseif lscore ≤ 32
            return 2
        else
            return 1
        end
    end

    if is_locked(s) && s.lock != w
        # opponent locked and did not achieve 66
        if s.stichlos
            return 3
        else
            return 2
        end
    end

    if wscore < 66 && lscore < 66
        # lasttrick
        return 1
    end
end

include("moves.jl")
