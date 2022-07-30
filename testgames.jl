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
