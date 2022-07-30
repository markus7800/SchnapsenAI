include("game2.jl")


s = Schnapsen("KC 10C JS 10D 10H", "AS")
g = Game(s)

# player 1
play_move_draw_card!(g, stringtomove("KC t")) # play one card from hand
g.s
# player 2
# win trick and draw QD, player 1 should get KH, AH should remain in talon
play_move_draw_card!(g, stringtomove("KS"), stringtocard("QD"))
g.s
# player 2
play_move_draw_card!(g, stringtomove("AC"))
g.s
# player 1
# lose and draw JD, player 2 should get QH, JH should remain in talon
play_move_draw_card!(g, stringtomove("10C"), stringtocard("JD"))
g.s
# player 2
play_move_draw_card!(g, stringtomove("JC"))
g.s
# player 1
# drawn card in opp hand, should force it to talon
play_move_draw_card!(g, stringtomove("AS"), stringtocard("QC"))
g.s




s = Schnapsen("KC 10C JS 10D 10H", "AS")
g = Game(s)

# player 1
play_move_draw_card!(g, stringtomove("KC t")) # play one card from hand
g.s

opp_move_draw_card!(g, stringtomove("AC"))
g.s


play_move_draw_card!(g, stringtomove(""))
play_move_draw_card!(g, stringtomove(""), stringtocard(""))
opp_move_draw_card!(g, stringtomove(""))
opp_move_draw_card!(g, stringtomove(""), stringtocard(""))

s = Schnapsen("", "")
s = Schnapsen("", "", "")


s = Schnapsen("JC QC QD JD AH", "10H")
g = Game(s)

play_move_draw_card!(g, stringtomove("AH"))
opp_move_draw_card!(g, stringtomove("QS"), stringtocard("10C"))



begin
    s = """JC QC AC KD QS - 1 - KH -
    JC : KC : 10C #
    QC : 10D : QD #
    QD : QH : AS #
    KD : AH z : * #
    AS : KS : * #
    QS : 10S : * #
    10C : AD : * #
    * : * : * #
    * : * : * #
    * : * : *"""
    g = game_from_str(s)
    println(g)
end

begin
    s = """JC QC AC KD QS - 1 - KH -
    JC : KC : 10C #
    * : 10D : *"""
    g = game_from_str(s)
    println(g)

    @assert g.s.player_to_move == g.perspective

    get_best_move(g)
end
