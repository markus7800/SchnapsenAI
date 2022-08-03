include("game2.jl")

begin
    s = """ -  -  -
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : * #
    * : * : *"""
    g = game_from_str(s)
    println(g)

    @assert g.s.player_to_move == g.perspective

    get_best_move(g)
end


s = """JS QH 10C 10H AS - 2 - JH - AC : 10H : QD #
KD : QD : QC #
AH : JS : KC #
KS a : AS : 10S #
10D : 10C : KH"""

g = game_from_str(s)


s = """JS QH 10C 10H AS - 2 - JH - AC : 10H : QD #
KD : QD : QC #
AH : JS : KC #
KS a : AS : 10S"""

s = """JS QH 10C 10H AS - 2 - JH - AC : * : *"""

get_best_move(g)
