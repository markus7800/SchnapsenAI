# http://schnapsen.realtype.at/index.php?page=spielregeln
# https://de.wikipedia.org/wiki/Schnapsen#Die_Regeln

struct Move
    card::Card
    call::Bool
    lock::Bool
    swap::Bool
end

function Base.show(io::IO, move::Move)
    print(io, move.card)
    if move.call || move.lock || move.swap
        print(io, " ")
    end
    if move.call
        print(io, "a")
    end
    if move.lock
        print(io, "z")
    end
    if move.swap
        print(io, "t")
    end
end

mutable struct MoveList <: AbstractArray{Move,1}
    moves::Array{Move,1}
    count::Int
end


function Base.iterate(list::MoveList, state = 1)
    if state > list.count
        nothing
    else
        (list.moves[state], state + 1)
    end
end


function Base.length(list::MoveList)
    list.count
end


function Base.eltype(::Type{MoveList})
    Move
end


function Base.size(list::MoveList)
    (list.count,)
end


function Base.IndexStyle(::Type{<:MoveList})
    IndexLinear()
end


function Base.getindex(list::MoveList, i::Int)
    list.moves[i]
end


function MoveList()
    MoveList(Array{Move}(undef, 20), 0)
end

function MoveList(moves::Vector{Move})
    list = MoveList()
    for (i,m) in enumerate(moves)
        list[i] = m
    end
    list.count = length(moves)
    return list
end

function Base.push!(list::MoveList, m::Move)
    list.count += 1
    list.moves[list.count] = m
end


function Base.push!(list::MoveList, m::Move)
    list.count += 1
    list.moves[list.count] = m
end

# make sure to have i <= list.count
function Base.setindex!(list::MoveList, v::Move, i::Int)
    list.moves[i] = v
end

function recycle!(list::MoveList)
    list.count = 0
end


function get_moves!(moves::MoveList, s::Schnapsen)
    hand = s.player_to_move == 1 ? s.hand1 : s.hand2

    if s.played_card == NOCARD
        # Spieler muss Karte ausspielen
        swap = false
        atoutjack = Card(s.atout, JACK)
        if s.n_talon ≥ 2 && !is_locked(s) && atoutjack in hand
            # Hält ein Spieler den Unter bzw. Buben der Trumpffarbe und ist am Zug,
            # darf er vor seinem Zug diese Karte gegen die offen aufliegende Trumpffarbe „austauschen“.
            # Die Vorhand darf die Trumpfkarte auch vor dem Ausspielen der ersten Karte austauschen.
            # Liegt nur noch eine Karte als Talon auf der offenen Trumpfkarte, darf man austauschen, jedoch nicht zudrehen.
            # DRS: Der Atout Bube darf auch ohne einen Stich ausgetauscht werden.
            # DRS: Der Atout Bube darf auch noch ausgetauscht werden, wenn nur mehr eine verdeckte Karte am Stapel liegt.
            swap = true
            push!(moves, Move(s.talon[1], false, false, true))
            push!(moves, Move(s.talon[1], false, true, true))
        end

        for card in hand
            f = face(card)
            st = suit(card)
            # normales auspielen
            # immer austauschen, außer wenn man bube auspielen will, reduziert moves
            push!(moves, Move(card, false, false, swap && card != atoutjack))

            if !is_locked(s) && s.n_talon ≥ 2
                # auspielen mit zudrehen
                # DRS: Zudrehen ist auch ohne einen Stich erlaubt.
                # DRS: Zudrehen ist auch erlaubt, wenn nur mehr eine verdeckte Karte am Stapel liegt.
                # (nicht wie Wikipedia: Zudrehen ist auch erlaubt, wenn nur mehr eine verdeckte Karte am Stapel liegt)
                push!(moves, Move(card, false, true, swap && card != atoutjack))
            end

            if (f == QUEEN && Card(st, KING) in hand) ||
                (f == KING && Card(st, QUEEN) in hand)
                # DRS: 20 bzw. 40 darf auch ohne einen Stich angesagt werden.
                # Die Punkte werden aber erst nach Erzielen eines Stiches gutgeschrieben.
                # DRS: Beim Ansagen von 20 bzw. 40 darf die Dame oder der König gespielt werden.

                # auspielen mit ansage
                push!(moves, Move(card, true, false, swap))

                if !is_locked(s) && s.n_talon ≥ 2
                    # auspielen mit ansage und zudrehen
                    push!(moves, Move(card, true, true, swap))
                end
            end
        end
    else
        # Spieler muss auf ausgespielte Karte reagieren
        pf = face(s.played_card)
        pst = suit(s.played_card)
        farbzwang = false
        stichzwang = false
        if (pst & hand) != NOCARDS
            # hat farbe, covers ps==atout
            farbzwang = true # kann ausgespielte Karte bedienen
            if face(last(pst & hand)) > pf
                # hat farbe mit höheren wert, kann stechen
                stichzwang = true
            end
        end
        if !farbzwang
            if (s.atout & hand) != NOCARDS
                # hat atout aber nicht farbe
                stichzwang = true
            end
        end

        # Ist der Talon aufgebraucht oder wurde er zugedreht, gilt ab diesem Zeitpunkt Farb- und Stichzwang;
        # das heißt ein Spieler muss, wenn er an der Reihe ist:
        # - mit einer höheren Karte der angespielten Farbe stechen. Kann er das nicht, so muss er
        # - eine niedrigere Karte der angespielten Farbe zugeben. Ist das nicht möglich, so muss er
        # - mit einer Trumpfkarte stechen, und falls auch das nicht geschehen kann,
        # - eine beliebige andere Karte abwerfen.
        # Farbzwang geht immer vor Stichzwang:
        # Es ist nicht erlaubt mit einer Trumpfkarte zu stechen, wenn man die angespielte Farbe bedienen kann.
        for card in hand
            f = face(card)
            st = suit(card)

            if is_locked(s) || s.n_talon == 0
                farbzwang && st != pst && continue # falsche farbe, Farbzwang geht immer vor Stichzwang
                if stichzwang
                    if !(
                        (st == pst && f > pf) || # gleiche farbe, größer wert
                        (st == s.atout && pst != s.atout) # verschiedene farbe, atout
                        )
                        continue
                    end
                end
            end

            push!(moves, Move(card, false, false, false))
        end
    end

    return moves
end
function get_moves(s::Schnapsen)
    moves = MoveList()
    get_moves!(moves, s)
    return moves
end

mutable struct Undo
    hand1::Cards
    hand2::Cards

    trickscore1::Int
    trickscore2::Int
    lasttrick::Int

    call1::Int
    call2::Int

    player_to_move::Int
    played_card::Card

    n_talon::Int
end


function Undo()::Undo
    Undo(NOCARDS, NOCARDS, 0, 0, 0, 0, 0, 0, NOCARD, 0)
end

function take_state!(undo::Undo, s::Schnapsen)
    undo.hand1 = s.hand1
    undo.hand2 = s.hand2

    undo.trickscore1 = s.trickscore1
    undo.trickscore2 = s.trickscore2
    undo.lasttrick = s.lasttrick

    undo.call1 = s.call1
    undo.call2 = s.call2

    undo.player_to_move = s.player_to_move
    undo.played_card = s.played_card

    undo.n_talon = s.n_talon
end

function make_move!(s::Schnapsen, move::Move, undo::Undo)

    take_state!(undo, s)

    if s.player_to_move == 1
        if move.swap
            # atout bube ausgetauscht
            atoutjack = Card(s.atout, JACK)
            @assert atoutjack in s.hand1
            s.hand1 = remove(s.hand1, atoutjack)
            s.hand1 = add(s.hand1, s.talon[1])
            s.talon[1] = atoutjack
        end
        s.hand1 = remove(s.hand1, move.card)
    else
        if !(move.card in s.hand2)
            # atout bube ausgetauscht
            atoutjack = Card(s.atout, JACK)
            @assert atoutjack in s.hand2
            s.hand2 = remove(s.hand2, atoutjack)
            s.hand2 = add(s.hand2, s.talon[1])
            s.talon[1] = atoutjack
        end
        s.hand2 = remove(s.hand2, move.card)
    end

    if s.played_card == NOCARD
        s.played_card = move.card

        if move.call
            # Besitzt ein Spieler König und Ober bzw. Dame von einer Farbe, so kann er dies, wenn er am Zug ist, ansagen (melden) und erhält dafür wie folgt Augen gutgeschrieben.
            # @assert face(move.card) == QUEEN || face(move.card) == KING # Wer eine Ansage macht, muss eine der beiden Karten zum nächsten Stich ausspielen.
            v = 20  # Eine Ansage in einer anderen Farbe zählt 20 Augen, man nennt dies einen Zwanziger.

            if isatout(s, move.card)
                v *= 2 # eine Ansage in Trumpf zählt 40 Augen, die Meldung in Atout wird daher Vierziger genannt.
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
            s.opp_trickscore_at_lock = opp_trickscore # wenn er (der Gegner) zum Zeitpunkt des Zudrehens einen Stich hatte
        end

        s.player_to_move = s.player_to_move == 1 ? 2 : 1
    else
        # decide trick (stich)

        f1 = face(s.played_card)
        s1 = suit(s.played_card)

        f2 = face(move.card)
        s2 = suit(move.card)


        won = false
        if isatout(s, move.card)
            if isatout(s, s.played_card)
                won = f1 < f2
            else
                won = true
            end
        else
            if isatout(s, s.played_card)
                won = false
            else
                won = s1 == s2 && f1 < f2
            end
        end

        v = value(f1) + value(f2)
        v1 = (won && s.player_to_move == 1) || (!won && s.player_to_move == 2) ? v : 0
        v2 = v - v1

        s.trickscore1 += v1
        s.trickscore2 += v2

        # draw cards
        if !is_locked(s) && s.n_talon ≥ 2
            c1 = s.talon[s.n_talon] # card for winner
            c2 = s.talon[s.n_talon-1] # card for loser
            s.n_talon -= 2
            if v1 > 0 # player 1 won
                s.hand1 = add(s.hand1, c1)
                s.hand2 = add(s.hand2, c2)
            else # player 2 won
                s.hand1 = add(s.hand1, c2)
                s.hand2 = add(s.hand2, c1)
            end
        end

        s.player_to_move = v1 > 0 ? 1 : 2
        s.lasttrick = s.player_to_move

        s.played_card = NOCARD
    end

end



function undo_move!(s::Schnapsen, move::Move, undo::Undo)
    v1 = s.trickscore1 - undo.trickscore1
    v2 = s.trickscore2 - undo.trickscore2

    s.trickscore1 = undo.trickscore1
    s.trickscore2 = undo.trickscore2
    s.lasttrick = undo.lasttrick

    s.call1 = undo.call1
    s.call2 = undo.call2

    s.player_to_move = undo.player_to_move

    if undo.played_card == NOCARD
        # karte wurde ausgespielt (weil vorher keine Karte ausgespielt war)
        if move.lock
            s.lock = 0
            s.opp_trickscore_at_lock = 0
        end
        if move.swap
            # atoutbube ausgetauscht
            if  undo.player_to_move == 1
                hand_before = undo.hand1
                hand_after = s.hand1
            else
                hand_before = undo.hand2
                hand_after = s.hand2
            end
            h = remove(hand_after, hand_before) # has swapped card or is empty
            #println(move, ": ", hand_after, " - ", hand_before, " = ", h)
            if h == NOCARDS
                # ausgetauscht und ausgespielt
                s.talon[1] = s.played_card
            else
                # ausgetauscht und behalten
                s.talon[1] = Card(h.cs)
            end
        end
    end

    s.n_talon = undo.n_talon

    s.hand1 = undo.hand1
    s.hand2 = undo.hand2


    s.played_card = undo.played_card
end

function move_value(s::Schnapsen, move::Move)

    cardatout = isatout(s, move.card)
    f1 = face(move.card)
    s1 = suit(move.card)
    v1 = value(f1)

    if s.played_card == NOCARD
        # welche karte auspielen?
        opp_hand = s.player_to_move == 1 ? s.hand2 : s.hand1

        val = 100 # punkte die ich bekomme wenn gegner optimal sticht
        for card in opp_hand
            f2 = face(card)
            s2 = suit(card)
            v2 = value(f2)

            v = v1 + v2

            won = false
            if cardatout
                if isatout(s, card)
                    won = f2 < f1
                else
                    won = true
                end
            else
                if isatout(s, card)
                    won = false
                else
                    won = s1 != s2 || f2 < f1
                end
            end

            if won
                val = min(val, v)
            else
                val = min(val, -v)
            end
        end

        if move.lock
            val += 25
        end
        if move.call
            val += 50
        end
        return val
    else
        # mit welcher karte stechen?
        card = s.played_card

        f2 = face(card)
        s2 = suit(card)
        v2 = value(f2)

        v = v1 + v2

        won = false
        if cardatout
            if isatout(s, card)
                won = f2 < f1
            else
                won = true
            end
        else
            if isatout(s, card)
                won = false
            else
                won = s1 != s2 || f2 < f1
            end
        end

        if won
            return v
        else
            return -v
        end
    end
end

# function move_lt(a::Move, b::Move, s::Schnapsen)::Bool
#     if a.lock < b.lock
#         return true
#     end
#     if a.lock == b.lock && a.call < b.call
#         return true
#     end
#     return move_value(s, a) < move_value(s, b)
# end

# 10S az
function stringtomove(str::String)
    sts = Dict(
        'S'=>SPADES, 'H'=>HEARTS, 'D'=>DIAMONDS, 'C'=>CLUBS,
        '♠'=>SPADES, '♡'=>HEARTS, '♢'=>DIAMONDS, '♣'=>CLUBS
        )
    fs = Dict("J"=>JACK, "Q"=>QUEEN, "K"=>KING, "10"=>TEN, "A"=>ACE)

    sgroups = split(str, " ")

    f = sgroups[1][1:end-1]
    st = sgroups[1][end]

    card = Card(sts[st], fs[f])

    call = false
    lock = false
    swap = false

    if length(sgroups) > 1
        call = occursin("a", sgroups[2]) # ansagen
        lock = occursin("z", sgroups[2]) # zudrehen
        swap = occursin("t", sgroups[2]) # tauschen
    end

    return Move(card, call, lock, swap)
end

function user_input(s::Schnapsen)::Move
    m = nothing
    ms = get_moves(s)
    println("Valid moves: ", ms)
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
    return m
end

function playloop(s::Schnapsen; player1=user_input, player2=user_input)
    s = deepcopy(s)

    while !is_gameover(s)
        println(s)
        ms = get_moves(s)

        m = s.player_to_move == 1 ? player1(s) : player2(s)

        @assert m in ms

        make_move!(s, m)
        println()
        println()
    end
    println(s)
    println()
    println("Winner: $(winner(s)) with $(winscore(s)) points.")
end
