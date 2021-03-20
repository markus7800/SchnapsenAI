
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

            if !is_locked(s) && length(s.talon) > 2
                # auspielen mit zudrehen
                push!(moves, Move(card, false, true))
            end

            if (f == QUEEN && Card(st, KING) in hand) ||
                (f == KING && Card(st, QUEEN) in hand)

                # auspielen mit ansage
                push!(moves, Move(card, true, false))

                if !is_locked(s) && length(s.talon) > 2
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

    c1::Card
    c2::Card
end

function Undo(s::Schnapsen, c1=Card(0), c2=Card(0))
    Undo(s.hand1, s.hand2, s.trickscore1, s.trickscore2, s.lasttrick,
        s.call1, s.call2, s.player_to_move, s.played_card, c1, c2)
end

function make_move!(s::Schnapsen, move::Move)::Undo

    undo = Undo(s)

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
        if !is_locked(s) && length(s.talon) ≥ 2
            c1 = pop!(s.talon)
            c2 = pop!(s.talon)
            if v1 > 0
                s.hand1 = add(s.hand1, c1)
                s.hand2 = add(s.hand2, c2)

            else
                s.hand1 = add(s.hand1, c2)
                s.hand2 = add(s.hand2, c1)
            end

            undo.c1 = c1
            undo.c2 = c2
        end

        s.player_to_move = v1 > 0 ? 1 : 2
        s.lasttrick = s.player_to_move

        s.played_card = NOCARD
    end

    return undo
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
        if move.lock
            s.lock = 0
            s.stichlos = false
        end
    end
    if undo.c1 != NOCARD && undo.c2 != NOCARD
        push!(s.talon, undo.c2)
        push!(s.talon, undo.c1)
    end

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

function playloop(s::Schnapsen; player1=userinput, player2=userinput)
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
