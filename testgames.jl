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
