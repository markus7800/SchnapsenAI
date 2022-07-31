
using Genie

import Genie.Router: route
import Genie.Renderer: respond
import JSON: json

include("game2.jl")

game_string = ""
incomplete_trick = ""

route("/") do
    @info "/home"
    serve_static_file("ui.html")
end

route("/newgame") do
    global game_string
    global incomplete_trick

    hand = params(:hand)
    lastatout = params(:atout)
    oppmove = params(:oppmove)

    @info "/negame" hand lastatout oppmove

    perspective = oppmove == "" ? "1" : "2"

    game_string = hand * " - " * perspective * " - " * lastatout * " - "
    if oppmove != ""
        incomplete_trick = oppmove * " : * : *"
    end

    try
        game = game_from_str(game_string * incomplete_trick)
        println(game.s)
        return respond(json(Dict(
            "ok" => true
        )))
    catch e
        @info e
        return respond(json(Dict(
            "ok" => false,
            "error" => sprint(e)
        )))
    end
end

@info "Start listening at localhost:8000"
up(8000, async=false)
