
include("cards.jl")


mutable struct Schnapsen
    talon::Vector{Card} # atoutcard is talon[1]
    n_talon::Int
    atout::Cards

    hand1::Cards
    hand2::Cards

    played_card::Card
    lock::Int
    opp_trickscore_at_lock::Int

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
    if l.played_card != r.played_card || l.lock != r.lock || l.opp_trickscore_at_lock != r.opp_trickscore_at_lock
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

    Schnapsen(
        cards,
        10,
        atout,

        hand1,
        hand2,

        NOCARD, # played_card
        0, # lock
        0, # opp_trickscore_at_lock

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
    show_schnapsen(io, s, 0)
end

function show_schnapsen(io::IO, s::Schnapsen, perspective=0)
    print(io, "Player 2: ")
    if perspective != 1
        for card in s.hand2
            print(io, card, " ")
        end
        println(io, ", $(s.trickscore2) (+ $(s.call2))")
    else
        println(io, "* "^length(s.hand2))
    end

    println(io, "Played: $(s.played_card)")

    print(io, "Talon: ")
    if s.n_talon > 0
        print(io, s.talon[1], " | ")

        for card in s.talon[2:s.n_talon]
            if perspective == 0
                print(io, card, " ")
            else
                print(io, "??", " ")
            end
        end
    end
    println(io)


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
        print(io, "* "^length(s.hand1))
        println(io, ", $(s.trickscore1) (+ $(s.call1))")
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
        # Hat der Spieler, der eine Ansage getätigt hat,
        # das gesamte Spiel über keinen Stich erzielt,
        # zählen die durch die Ansage erzielten Augen nicht.
        # Wurde die Karte der Ansage gestochen und der Spieler erzielt später einen Stich,
        # zählen die durch die Ansage erzielten Augen dennoch.
        # DRS: 20 bzw. 40 darf auch ohne einen Stich angesagt werden.
        # Die Punkte werden aber erst nach Erzielen eines Stiches gutgeschrieben.
        score += call
    end

    return score
end

function is_gameover(s::Schnapsen)
    if s.played_card != NOCARD
        # Karte wurde ausgespielt, Gegner muss antworten
        return false
    end

    score1 = playerscore(s, 1)
    score2 = playerscore(s, 2)

    if score1 ≥ 66 || score2 ≥ 66
        # Hat ein Spieler nach Gewinn eines Stichs oder einer Ansage (s. u.) 66
        # oder mehr Augen erreicht, so darf er sich ausmelden.
        # Das Spiel ist beendet, und jeder Spieler zählt die gesammelten Augen.
        return true
    end

    if length(s.hand1) + length(s.hand2) == 0
        # Alle Karten ausgespielt.
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

    # Kann der Spieler, der den Talon gesperrt hat, keine 66 Augen erzielen,
    # bzw. kann sich sein Gegner zuvor ausmelden, so gewinnt der Gegner
    if score1 < 66 && s.lock == 1
        return 2
    end
    if score2 < 66 && s.lock == 2
        return 1
    end

    if score1 < 66 && score2 < 66
        # Hat vor dem Ausspielen der letzten Karte kein Spieler das Spiel
        # für gewonnen erklärt, muss die letzte Karte gespielt werden und
        # es gewinnt derjenige das Spiel, der den letzten Stich erzielt.
        # Wer den letzten Stich erzielen kann, spielt im Falle einer Talonsperre keine Rolle.

        # DRS: Wenn kein Spieler im Spielverlauf ausruft, gilt der Gewinner des letzten Stichs als Sieger.
        return s.lasttrick
    end

    return 0
end

function winscore(s::Schnapsen)
    w = winner(s)
    l = w == 1 ? 2 : 1
    wscore = playerscore(s, w)
    lscore = playerscore(s, l)

    # Kann der Spieler, der den Talon gesperrt hat, keine 66 Augen erzielen,
    # bzw. kann sich sein Gegner zuvor ausmelden, so gewinnt der Gegner
    if is_locked(s) && s.lock != w
        # opponent locked and did not achieve 66
        if s.opp_trickscore_at_lock == 0
            # drei Punkte, falls er zum Zeitpunkt des Zudrehens noch stichlos war
            return 3
        else
            # ansonsten zwei Punkte
            return 2
        end
    end
    if is_locked(s) && s.lock == w
        # Wenn ein Spieler zudreht, werden die Punkte des Gegners eingefroren.
        # Das heißt, der zudrehende Spieler erzielt 2 Punkte, wenn der Spieler
        # zum Zeitpunkt des Zudrehens weniger als 33 Punkte hatte.
        if s.opp_trickscore_at_lock == 0
            # Hat der Gegner keinen Stich erzielt, gewinnt der Spieler drei Punkte.
            return 3
        elseif s.opp_trickscore_at_lock ≤ 32
            # Hat der Gegner 32 oder weniger Augen erhalten, gewinnt der Spieler zwei Punkte
            return 2
        else
            # Hat der Gegner 33 oder mehr Augen erhalten, gewinnt der Spieler einen Punkt.
            return 1
        end
    end

    # Hat ein Spieler nach Gewinn eines Stichs oder einer Ansage
    # 66 oder mehr Augen erreicht, so darf er sich ausmelden.
    # Das Spiel ist beendet, und jeder Spieler zählt die gesammelten Augen.
    if wscore ≥ 66
        if lscore == 0
            # Hat der Gegner keinen Stich erzielt, gewinnt der Spieler drei Punkte.
            return 3
        elseif lscore ≤ 32
            # Hat der Gegner 32 oder weniger Augen erhalten, gewinnt der Spieler zwei Punkte
            return 2
        else
            # Hat der Gegner 33 oder mehr Augen erhalten, gewinnt der Spieler einen Punkt.
            return 1
        end
    end

    if wscore < 66 && lscore < 66
        # lasttrick
        return 1
    end
end


# 10S
const string_to_suite = Dict(
    'S'=>SPADES, 'H'=>HEARTS, 'D'=>DIAMONDS, 'C'=>CLUBS,
    '♠'=>SPADES, '♡'=>HEARTS, '♢'=>DIAMONDS, '♣'=>CLUBS
    )
const string_to_face = Dict("J"=>JACK, "Q"=>QUEEN, "K"=>KING, "10"=>TEN, "A"=>ACE)


function stringtocard(str::AbstractString)::Card
    sgroups = split(str, " ")

    f = sgroups[1][1:end-1]
    st = sgroups[1][end]

    card = Card(string_to_suite[st], string_to_face[f])
    return card
end

function Schnapsen(hand1::String, hand2::String, talon::String)

    h1 = NOCARDS
    for c_str in split(hand1, " ")
        card = stringtocard(c_str)
        #println(c_str, ": ", card)
        h1 = add(h1, card)
    end

    h2 = NOCARDS
    for c_str in split(hand2, " ")
        card = stringtocard(c_str)
        #println(c_str, ": ", card)
        h2 = add(h2, card)
    end

    t = Vector{Card}()
    for c_str in split(talon, " ")
        card = stringtocard(c_str)
        # println(c_str, ": ", card)
        push!(t, card)
    end

    s = Schnapsen()
    s.hand1 = h1
    s.hand2 = h2
    s.talon = t
    s.atout = suit(s.talon[1])
    return s
end


function Schnapsen(hand1::String, last_atout::String)

    h1 = NOCARDS
    for c_str in split(hand1, " ")
        card = stringtocard(c_str)
        #println(c_str, ": ", card)
        h1 = add(h1, card)
    end

    last_atout = stringtocard(last_atout)
    remaining = remove(ALLCARDS, h1)
    remaining = remove(remaining, last_atout)
    remaining = collect(remaining)

    h2 = reduce(|, remaining[1:5]) # just fill hand2

    t = fill(NOCARD, 10)
    t[2:10] = remaining[6:end] # just fill talon
    t[1] = last_atout

    s = Schnapsen()
    s.hand1 = h1
    s.hand2 = h2
    s.talon = t
    s.atout = suit(s.talon[1])
    return s
end


function Schnapsen(hand::String, last_atout::String, oppmove::String)

    # build opponent hand such that oppmove is legal
    h2 = NOCARDS
    for c_str in split(hand, " ")
        card = stringtocard(c_str)
        #println(c_str, ": ", card)
        h2 = add(h2, card)
    end

    last_atout = stringtocard(last_atout)
    oppmove = stringtomove(oppmove)
    @assert !(oppmove.card in h2)

    remaining = remove(ALLCARDS, h2)
    remaining = remove(remaining, last_atout)
    remaining = remove(remaining, oppmove.card)

    h1 = NOCARDS
    if oppmove.card != last_atout # tauschen müssen und ausspielen -> nicht in der hand
        h1 = add(h1, oppmove.card)
    end

    if oppmove.call
        spouse = face(oppmove.card) == KING ? QUEEN : KING
        spouse = Card(suit(oppmove.card), spouse)
        @assert !(spouse in h2)
        remaining = remove(remaining, spouse)
        h1 = add(h1, spouse)
    end
    if oppmove.swap
        atout_jack = Card(suit(last_atout), JACK)
        @assert !(atout_jack in h2)
        h1 = add(h1, atout_jack)
        remaining = remove(remaining, atout_jack)
    end

    remaining = collect(remaining)
    #println(remaining, "; ", length(remaining))

    to_add = 5-length(h1)
    #println("to_add ", to_add)
    h1 = add(h1, reduce(|, remaining[1:to_add])) # just fill hand2s
    #println("h1 ", h1, ", ", length(h1))

    t = fill(NOCARD, 10)
    t[2:10] = remaining[(to_add+1):end] # just fill talon
    t[1] = last_atout

    s = Schnapsen()
    s.hand1 = h1
    s.hand2 = h2
    s.talon = t
    s.atout = suit(s.talon[1])

    @assert oppmove in get_moves(s)
    make_move!(s, oppmove, Undo())

    return s
end

# test cases

# s = Schnapsen("KC 10C JS 10D 10H", "AS", "10C") # fail: card in my hand
# s = Schnapsen("KC 10C JS 10D 10H", "AS", "10S") # ok
# s = Schnapsen("KC 10C JS 10D 10H", "AS", "KH a") # ok: QH should be in hand
# s = Schnapsen("KC 10C JS 10D 10H", "AS", "KH az") # ok
# s = Schnapsen("KC 10C JS 10D 10H", "AS", "KH t") # fail: atoutjack in my hand
# s = Schnapsen("KC 10C JH 10D 10H", "AS", "KH t") # ok
# s = Schnapsen("KC 10C JH 10D 10H", "AS", "AS t") # ok
# s = Schnapsen("KC 10C JH 10D 10H", "AS", "AS") # fail: atoutjack not swapped
# s = Schnapsen("KC 10C JH 10D 10H", "AS", "AS tz") # ok
# s = Schnapsen("KS 10C JH 10D 10H", "AS", "QS atz") # fail: spouse in my hand
# s = Schnapsen("KS 10C JH 10D 10H", "AS", "QH atz") # ok



include("moves.jl")
