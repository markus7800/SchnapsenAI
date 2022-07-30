"initial_hand - perspective - last_atout - card_player_1 : card_player_2 : drawn_card # ..."
function game_from_str(s)
    s = replace(s, "\n" => " ")
    game = Game(0)

    initial_hand, perspective, last_atout, history = split(s," - ")
    perspective = parse(Int, perspective)
    game.perspective = perspective

    last_atout = stringtocard(last_atout)
    game.s.atout = suit(last_atout)

    if length(history) == 0
        @assert perspective == 1
    end


    h = NOCARDS
    for c_str in split(initial_hand, " ")
        card = stringtocard(c_str)
        #println(c_str, ": ", card)
        h = add(h, card)
    end
    @assert length(h) == 5

    if perspective == 1
        h1 = h
        h2 = NOCARDS
    else
        h2 = h
        h1 = NOCARDS
    end
    hs = [h1, h2]
    println(hs)
    println("last_atout: ", last_atout)

    played_cards = NOCARDS

    last_drawn_card = NOCARD
    if length(history) > 0
        function process_move(m::Move, player::Int)
            @assert !(m.card in played_cards)

            if player == perspective
                @assert m.card in hs[perspective]
            else
                @assert !(m.card in hs[perspective])
            end

            if m.swap
                atout_jack = Card(game.s.atout, JACK)
                @assert last_atout != atout_jack
                if player == perspective
                    @assert atout_jack in hs[perspective]
                else
                    @assert !(atout_jack in hs[perspective])
                end

                game.atout_swap = last_atout
                game.atout_swap_player = player

                hs[player] = add(hs[player], last_atout)
                hs[player] = remove(hs[player], atout_jack)
                last_atout = atout_jack
            end
            if m.call
                v = 20
                if isatout(game.s, m.card)
                    v *= 2
                end
                if player == 1
                    game.s.call1 += v
                else
                    game.s.call2 += v
                end

                spouse = face(m.card) == KING ? QUEEN : KING
                spouse = Card(suit(m.card), spouse)
                @assert !(spouse in played_cards)
                if player == perspective
                    @assert spouse in hs[perspective] "$spouse"
                else
                    @assert !(spouse in hs[perspective])
                end
                push!(game.calls, (spouse, player))
            end
            if m.lock
                game.s.lock = player
                game.s.opp_trickscore_at_lock = player == 1 ? game.s.trickscore2 : game.s.trickscore1
            end

            played_cards = add(played_cards, m.card)
            hs[player] = remove(hs[player], m.card)
        end


        player_to_move = 1
        for (i, step) in enumerate(split(history, " # "))
            m1, m2, d = split(step, " : ")
            println(i, ": ", m1, ",", m2, ",", d)
            if m1 == "*" && m2 == "*" && d == "*"
                break
            end

            @assert !(m1 == "*" && m2 == "*")

            trick_incomplete = m1 == "*" || m2 == "*"

            if is_locked(game.s)
                @assert d == "*"
            else
                if trick_incomplete
                    @assert d == "*"
                else
                    if stringtomove(m1).lock || stringtomove(m2).lock
                        @assert d == "*"
                    else
                        @assert d != "*"
                    end
                end
            end

            if trick_incomplete
                player_to_move == 1 && @assert m1 != "*"
                player_to_move == 2 && @assert m2 != "*"

                if player_to_move == 1
                    m = stringtomove(m1)
                else
                    m = stringtomove(m2)
                end

                if is_locked(game.s)
                    @assert !m.lock
                end

                process_move(m, player_to_move)

                game.s.played_card = m.card

                player_to_move = player_to_move == 1 ? 2 : 1

            else
                m1 = stringtomove(m1)
                m2 = stringtomove(m2)


                process_move(m1, 1)
                process_move(m2, 2)

                if d != "*"
                    @assert !is_locked(game.s)
                    d = stringtocard(d)
                    @assert !(d in played_cards)
                    hs[perspective] = add(hs[perspective], d)
                    last_drawn_card = d
                end

                # decide trick
                played_card = player_to_move == 1 ? m1.card : m2.card
                m = player_to_move == 1 ? m2 : m1
                move_card = m.card
                @assert !m.lock
                @assert !m.call
                @assert !m.swap

                player_to_move = player_to_move == 1 ? 2 : 1

                f1 = face(played_card)
                s1 = suit(played_card)

                f2 = face(move_card)
                s2 = suit(move_card)

                won = false
                if isatout(game.s, move_card)
                    if isatout(game.s, played_card)
                        won = f1 < f2
                    else
                        won = true
                    end
                else
                    if isatout(game.s, played_card)
                        won = false
                    else
                        won = s1 == s2 && f1 < f2
                    end
                end

                v = value(f1) + value(f2)
                v1 = (won && player_to_move == 1) || (!won && player_to_move == 2) ? v : 0
                v2 = v - v1

                game.s.trickscore1 += v1
                game.s.trickscore2 += v2

                player_to_move = v1 > 0 ? 1 : 2
                game.s.lasttrick = player_to_move

                game.s.played_card = NOCARD
            end

            println("player_hand: ", hs[perspective], ", played_cards: ", played_cards, ", last_atout: ", last_atout, ", player_to_move: ", player_to_move)
        end

        game.s.player_to_move = player_to_move
    end

    game.played_cards = played_cards
    game.last_atout = last_atout

    remaining = ALLCARDS
    remaining = remove(remaining, hs[perspective])
    remaining = remove(remaining, played_cards)
    if length(played_cards) < 20
        remaining = remove(remaining, last_atout)
    end

    remaining = collect(remaining)
    n_opp_hand = length(hs[perspective])
    if game.s.played_card != NOCARD
        if game.s.player_to_move == perspective
            # opponent played card
            n_opp_hand -= 1
        else
            # player played card
            n_opp_hand += 1
        end
    end

    opp_hand = reduce(|, remaining[1:n_opp_hand], init=NOCARDS)

    remaining = remaining[n_opp_hand+1:end]
    println()
    println("player_hand: ", hs[perspective], " ", length(hs[perspective]), ", played_cards: ", played_cards, " ", length(played_cards), ", last_atout: ", last_atout)
    println("opp_hand: ", opp_hand, " ", length(opp_hand), ", remaining: ", remaining, " ", length(remaining))

    talon = remaining

    if length(remaining) == 0
        if game.s.lasttrick == perspective
            # opponent gets last_atout
            @assert last_atout != last_drawn_card
        else
            @assert last_atout == last_drawn_card
        end
        n_talon = 0
    else
        @assert (length(remaining) + 1) % 2 == 0
        n_talon = length(remaining) + 1
        insert!(talon, 1, last_atout)
    end

    @assert length(talon) == n_talon
    game.s.n_talon = n_talon
    game.s.talon = talon

    if perspective == 1
        game.s.hand1 = hs[perspective]
        game.s.hand2 = opp_hand
    else
        game.s.hand1 = opp_hand
        game.s.hand2 = hs[perspective]
    end

    cards = played_cards
    cards = add(cards, game.s.hand1)
    cards = add(cards, game.s.hand2)
    talon_cards = reduce(|, game.s.talon, init=NOCARDS)
    cards = add(cards, talon_cards)
    @assert cards == ALLCARDS
    @assert game.s.hand1.cs & game.s.hand2.cs == 0
    @assert game.s.hand1.cs & talon_cards.cs == 0
    @assert game.s.hand2.cs & talon_cards.cs == 0

    println()

    return game
end

# s = "KC 10C JS 10D 10H - 1 - AS - ";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : * : *";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # * : AC : *";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # * : JC : *";
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC a : * : *"; # should fail
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC z : * : *";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC z : JC : *"; # should fail
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC z : KH a : *"; # should fail
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC z : QH : KH"; # should fail
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC z : QH : *";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : *"; # should fail
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : KH";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : KH # QD : * : *";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : KH # QD : AD : JS";
#
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : KH # QD : AD : AH"; # should fail, last trick by opponent
# s = "KC 10C JS 10D 10H - 1 - AS - KC t : KS : QD # 10C : AC : JD # AS : JC : QC # QC : QH : KH # QD : AD : KC"; # should fail, card already played
#
# game_from_str(s)
#
# s = "KC 10C JS 10D 10H - 2 - AS - KC t : * : *"; # should fail, opponent plays my card
# s = "KS 10C JS 10D 10H - 2 - AS - KC t : * : *"; # should fail, I have atoutjack
#
# s = "KS 10C JC 10D 10H - 2 - AS - KC t : * : *";
#
# s = """KC 10C JS 10D 10H - 1 - AS -
# KC t : KS : QD #
# 10C : AC : JD #
# AS : JC : QC #
# QC : QH : KH #
# QD : AD : JS #
# * : * : *"""
#
#
# begin
#     s = """ -  -  -
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : * #
#     * : * : *"""
#     game_from_str(s)
#     println(game)
# end
#
