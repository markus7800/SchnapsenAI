
function play_move_draw_card!(game::Game, m::Move, c::Card=NOCARD)
    @assert m.card != c

    my_hand = game.s.player_to_move == 1 ? game.s.hand1 : game.s.hand2
    opp_hand = game.s.player_to_move == 1 ? game.s.hand2 : game.s.hand1

    legal_moves = get_moves(game.s)
    @assert m in legal_moves "Illegal move $m : $legal_moves"
    game.played_cards = add(game.played_cards, m.card)
    if m.call
        spouse = face(m.card) == KING ? QUEEN : KING
        push!(game.calls, (Card(suit(m.card), spouse), m.player_to_move))
    end

    if m.swap
        game.atout_swap = game.s.talon[1] # before we make move
        game.atout_swap_player = game.s.player_to_move
    end

    if c == NOCARD
        # keine karte aufnehmen, -> gerade auspielen
        @assert game.s.played_card == NOCARD
        make_move!(game.s, m, Undo())
    else
        # karte aufnehmen -> auf gegner karte reagieren
        @assert game.s.played_card != NOCARD
        u = Undo()
        me = game.s.player_to_move
        make_move!(game.s, m, u)
        last_trick = game.s.lasttrick

        # place drawn card correctly
        undo_move!(game.s, m, u)

        # drawn card cannot be in opp hand
        if c in opp_hand
            opp_hand = remove(opp_hand, c)
            opp_hand = add(opp_hand, s.talon[2])
            s.talon[2] = c
        end

        current = 0
        for i in 1:s.n_talon
            if s.talon[i] == c
                current = i
                break
            end
        end
        @assert current != 0 # drawn card has to be in talon

        new = 0
        if me == last_trick
            new = s.n_talon
        else
            new = s.n_talon-1
        end
        s.talon[current] = s.talon[new]
        s.talon[new] = c

        make_move!(game.s, m, u)
    end

    game.last_atout = game.s.talon[1]

    game.s
end

function opp_move_draw_card!(game::Game, m::Move, c::Card=NOCARD) # card c is not for opponent but for me
    @assert m.card != c

    my_hand = game.s.player_to_move == 1 ? game.s.hand2 : game.s.hand1
    opp_hand = game.s.player_to_move == 1 ? game.s.hand1 : game.s.hand2

    @assert !(m.card in game.played_cards) # contains current played card
    @assert !(m.card in my_hand)

    # build opponent hand and talon such that move is legal

    remaining = remove(ALLCARDS, game.played_cards)
    remaining = remove(remaining, my_hand)
    remaining = remove(remaining, game.last_atout)
    remaining = remove(remaining, m.card)
    remaining = remove(remaining, c) # cannot have the card that i draw

    h = NOCARDS
    if m.card != game.last_atout # tauschen müssen und ausspielen -> nicht in der hand
        h = add(h, m.card)
    end

    if m.call
        spouse = face(m.card) == KING ? QUEEN : KING
        spouse = Card(suit(m.card), spouse)
        @assert !(spouse in my_hand)
        @assert !(spouse in game.played_cards)
        remaining = remove(remaining, spouse)
        h = add(h, spouse)
    end
    if m.swap
        atout_jack = Card(suit(last_atout), JACK)
        @assert !(atout_jack in my_hand)
        @assert !(atout_jack in game.played_cards)
        h = add(h, atout_jack)
        remaining = remove(remaining, atout_jack)
    end

    remaining = collect(remaining)
    if c != NOCARD
        @assert !(c in remaining)
        push!(remaining, c) # card to talon
    end

    println(remaining, "; ", length(remaining))

    to_add = length(opp_hand)-length(h)
    println("to_add ", to_add)
    h = add(h, reduce(|, remaining[1:to_add])) # just fill hand
    println("h ", h, ", ", length(h))

    t = fill(NOCARD, game.s.n_talon)
    t[2:game.s.n_talon] = remaining[(to_add+1):end] # just fill talon
    t[1] = game.last_atout
    println("talon ", t, ", ", length(t))

    if game.s.player_to_move == 1
        game.s.hand1 = h
    else
        game.s.hand2 = h
    end
    s.talon = t


    # make game move

    legal_moves = get_moves(game.s)
    @assert m in legal_moves "Illegal move $m : $legal_moves"
    game.played_cards = add(game.played_cards, m.card)

    if m.call
        spouse = face(m.card) == KING ? QUEEN : KING
        push!(game.calls, (Card(suit(m.card), spouse), m.player_to_move))
    end

    if m.swap
        game.atout_swap = game.s.talon[1] # before we make move
        game.atout_swap_player = game.s.player_to_move
    end

    if c == NOCARD
        # keine karte aufnehmen, -> gegner spielt aus
        @assert game.s.played_card == NOCARD
        make_move!(game.s, m, Undo())
    else
        # karte aufnehmen -> gegner reagiert auf unsere karte
        @assert game.s.played_card != NOCARD
        u = Undo()
        make_move!(game.s, m, u)

        me = game.s.player_to_move
        last_trick = game.s.lasttrick

        # place drawn card correctly
        undo_move!(game.s, m, u)
        current = 0
        for i in 1:s.n_talon
            if s.talon[i] == c
                current = i
                break
            end
        end
        @assert current != 0 # drawn card has to be in talon

        new = 0
        if me == last_trick
            new = s.n_talon
        else
            new = s.n_talon-1
        end
        s.talon[current] = s.talon[new]
        s.talon[new] = c

        make_move!(game.s, m, u)
    end

    game.last_atout = game.s.talon[1]

    game.s
end
