

struct Cards
    cs::UInt64
end

function Base.:|(left::Cards, right::Cards)::Cards
    return Cards(left.cs | right.cs)
end

function Base.:&(left::Cards, right::Cards)::Cards
    return Cards(left.cs & right.cs)
end

function Base.length(cards::Cards)
    count_ones(cards.cs)
end

struct Card
    c::UInt64
end # where only one bit set

function Base.in(card::Card, cards::Cards)
    card.c & cards.cs > 0
end

function remove(cards::Cards, card::Card)
    Cards(cards.cs ⊻ card.c)
end

function add(cards::Cards, card::Card)
    Cards(cards.cs | card.c)
end

struct Face
    f::UInt
end

const CLUBS = Cards(31)
const SPADES = Cards(CLUBS.cs << 8)
const DIAMONDS = Cards(SPADES.cs << 8)
const HEARTS = Cards(DIAMONDS.cs << 8)

const JACK = Face(2^0)
const QUEEN = Face(2^1)
const KING = Face(2^2)
const TEN = Face(2^3)
const ACE = Face(2^4)

function Base.:<(f1::Face, f2::Face)
    return f1.f < f2.f
end

function value(face::Face)
    if face == JACK
        return 2
    elseif face == QUEEN
        return 3
    elseif face == KING
        return 4
    elseif face == TEN
        return 10
    elseif face == ACE
        return 11
    else
        error("Invalid face.")
    end
end

const NOCARD = Card(0)
const NOCARDS = Cards(0)

function Card(suit::Cards, face::Face)::Card
    return Card(face.f << trailing_zeros(suit.cs))
end

function suit(card::Card)::Cards
    if card.c & CLUBS.cs > 0
        return CLUBS
    elseif card.c & SPADES.cs > 0
        return SPADES
    elseif card.c & DIAMONDS.cs > 0
        return DIAMONDS
    elseif card.c & HEARTS.cs > 0
        return HEARTS
    else
        return Cards(0)
    end
end

function face(card::Card)::Face
    t = trailing_zeros(card.c) ÷ 8
    return Face(card.c >> (8*t))
end

const SUIT_SYMBOLS = Dict{Cards, Char}(
    CLUBS => '♣',
    SPADES => '♠',
    DIAMONDS => '♢',
    HEARTS => '♡'
)

const FACE_SYMBOLS = Dict{Face, String}(
    JACK => "J",
    QUEEN => "Q",
    KING => "K",
    TEN => "10",
    ACE => "A"
)

# from right
function first(cards::Cards)::Card
    # trailing_zeros is Int for UInt64
    Card(1 << trailing_zeros(cards.cs))
end

function last(cards::Cards)::Card
    # trailing_zeros is Int for UInt64
    Card(1 << (64-leading_zeros(cards.cs)-1))
end

function removefirst(cards::Cards)::Cards
    Cards(cards.cs & (cards.cs - 1))
end

import Base.iterate
function Base.iterate(ss::Cards, state = ss)
    if state.cs == 0
        nothing
    else
        (first(state), removefirst(state))
    end
end


import Base.show
function show(io::IO, card::Card)
    if card == NOCARD
        print(io, "NOCARD")
    else
        s = suit(card)
        f = face(card)
        print(io, FACE_SYMBOLS[f] * SUIT_SYMBOLS[s])
    end
end

function show(io::IO, cards::Cards)
    if cards == NOCARDS
        print(io, "NOCARDS")
        return
    end

    for suit in [CLUBS, SPADES, DIAMONDS, HEARTS]
        suit_cards = Cards(suit.cs & cards.cs)
        if suit_cards != NOCARDS
            print(io, SUIT_SYMBOLS[suit])
            for card in suit_cards
                print(io, FACE_SYMBOLS[face(card)])
            end
            print(io, " ")
        end
    end
end

mutable struct Schnapsen
    talon::Vector{Card}
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

function isatout(s::Schnapsen, card::Card)
    (s.atout.cs & card.c) != 0
end


function all_cards()
    cards = Vector{Card}()
    for s in [CLUBS, SPADES, DIAMONDS, HEARTS]
        for f in [JACK, QUEEN, KING, TEN, ACE]
            push!(cards, Card(s, f))
        end
    end
    return cards
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
    print(io, "Player 2: ")
    for card in s.hand2
        print(io, card, " ")
    end
    println(io, ", $(s.trickscore2) (+ $(s.call2))")

    println(io, "Played: $(s.played_card)")

    print(io, "Talon: ")
    for card in s.talon
        print(io, card, " ")
    end
    println(io)
    print(io, "atout: $(SUIT_SYMBOLS[s.atout]), ")
    if is_locked(s)
        println(io, "locked by $(s.lock).")
    else
        println(io, "not locked.")
    end


    print(io, "Player 1: ")
    for card in s.hand1
        print(io, card, " ")
    end
    println(io, ", $(s.trickscore1) (+ $(s.call1))")

    print(io, "Next Player: $(s.player_to_move)")
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

struct Move
    card::Card
    call::Bool
    lock::Bool
end

function Base.show(io::IO, move::Move)
    print(io, move.card)
    if move.call
        print(io, ", angesagt")
    end
    if move.lock
        print(io, ", zugedreht")
    end
end

function get_moves(s::Schnapsen)
    moves = Vector{Move}()

    hand = s.player_to_move == 1 ? s.hand1 : s.hand2

    if s.played_card == NOCARD
        for card in hand
            f = face(card)
            st = suit(card)
            # normales auspielen
            push!(moves, Move(card, false, false))

            if !is_locked(s) && length(s.talon) > 0
                # auspielen mit zudrehen
                push!(moves, Move(card, false, true))
            end

            if (f == QUEEN && Card(st, KING) in hand) ||
                (f == KING && Card(st, QUEEN) in hand)

                # auspielen mit ansage
                push!(moves, Move(card, true, false))

                if !is_locked(s) && length(s.talon) > 0
                    # auspielen mit ansage und zudrehen
                    push!(moves, Move(card, true, true))
                end
            end
        end
    else
        pf = face(s.played_card)
        pst = suit(s.played_card)
        farbzwang = false
        stichzwang = false
        if (pst & hand) != NOCARDS
            # hat farbe, covers ps==atout
            farbzwang = true
            if face(last(pst & hand)) > pf
                stichzwang = true
            end
        end
        if !farbzwang
            if (s.atout & hand) != NOCARDS
                # hat atout aber nicht farbe
                stichzwang = true
            end
        end


        for card in hand
            f = face(card)
            st = suit(card)

            if is_locked(s) || length(s.talon) == 0
                farbzwang && st != pst && continue # falsche farbe
                if stichzwang
                    if !(
                        (st == pst && f > pf) || # gleiche farbe, größer wert
                        (st == s.atout && pst != s.atout) # verschiedene farbe, atout
                        )
                        continue
                    end
                end
            end

            push!(moves, Move(card, false, false))
        end
    end

    return moves
end


function make_move!(s::Schnapsen, move::Move)
    if s.player_to_move == 1
        @assert move.card in s.hand1
    else
        @assert move.card in s.hand2
    end

    if s.player_to_move == 1
        s.hand1 = remove(s.hand1, move.card)
    else
        s.hand2 = remove(s.hand2, move.card)
    end

    if s.played_card == NOCARD
        s.played_card = move.card

        if move.call
            @assert face(move.card) == QUEEN || face(move.card) == KING
            v = 20
            if isatout(s, move.card)
                v *= 2
            end
            if s.player_to_move == 1
                s.call1 += v
            else
                s.call2 += v
            end
        end
        if move.lock
            s.lock = s.player_to_move
            opp_trickscore = s.player_to_move == 1 ? s.trickscore2 : s.trickscore1
            s.stichlos = opp_trickscore == 0
        end

        s.player_to_move = s.player_to_move == 1 ? 2 : 1
    else
        # decide trick (stich)

        f1 = face(s.played_card)
        f2 = face(move.card)

        won = false
        if isatout(s, move.card)
            if isatout(s, s.played_card)
                won = f1 < f2
            else
                won = true
            end
        else
            won = f1 < f2
        end

        v = value(f1) + value(f2)
        v1 = (won && s.player_to_move == 1) || (!won && s.player_to_move == 2) ? v : 0
        v2 = v - v1

        s.trickscore1 += v1
        s.trickscore2 += v2

        # draw cards
        if !is_locked(s)
            c1 = pop!(s.talon)
            c2 = pop!(s.talon)
            if v1 > 0
                s.hand1 = add(s.hand1, c1)
                s.hand2 = add(s.hand2, c2)
                s.lasttrick = 1
            else
                s.hand1 = add(s.hand1, c2)
                s.hand2 = add(s.hand2, c1)
                s.lasttrick = 2
            end
        end

        s.player_to_move = v1 > 0 ? 1 : 2

        s.played_card = NOCARD
    end

    s
end

function stringtomove(str::String)
    sts = Dict('S'=>SPADES, 'H'=>HEARTS, 'D'=>DIAMONDS, 'C'=>CLUBS)
    fs = Dict("J"=>JACK, "Q"=>QUEEN, "K"=>KING, "10"=>TEN, "A"=>ACE)

    sgroups = split(str, " ")

    f = sgroups[1][1:end-1]
    st = sgroups[1][end]

    card = Card(sts[st], fs[f])

    call = false
    lock = false

    if length(sgroups) > 1
        call = occursin("a", sgroups[2])
        lock = occursin("z", sgroups[2])
    end

    return Move(card, call, lock)
end

function playloop(seed=0)
    s = Schnapsen(seed)

    while !is_gameover(s)
        println(s)
        ms = get_moves(s)
        println("Valid moves: ", ms)

        m = nothing
        while isnothing(m)
            print("Player $(s.player_to_move) to move: ")
            try
                str = readline()
                move = stringtomove(str)
                if move in ms
                    m = move
                end
            catch e
                println(e)
                if e isa InterruptException
                    break
                end
            end
        end

        make_move!(s, m)
        println()
        println()
    end
    println(s)
    println()
    println("Winner: $(winner(s)) with $(winscore(s)) points.")
end
