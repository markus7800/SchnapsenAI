
using Genie

import Genie.Router: route
import Genie.Renderer: respond
import JSON: json

include("game2.jl")

game_string = ""
incomplete_trick = ""

const suit_names = Dict{Cards, String}(
    CLUBS => "clubs",
    SPADES => "spades",
    DIAMONDS => "diamonds",
    HEARTS => "hearts"
)

const face_names = Dict{Face, String}(
    JACK => "jack",
    QUEEN => "queen",
    KING => "king",
    TEN => "ten",
    ACE => "ace"
)

function card_to_name(card::Card)::String
    if card == NOCARD
        return "no_card"
    end
    s = suit(card)
    f = face(card)
    return suit_names[s] * "_" * face_names[f]
end

function game_to_json(game::Game)
    hand = game.perspective == 1 ? game.s.hand1 : game.s.hand2
    opphand = game.perspective == 1 ? game.s.hand2 : game.s.hand1
    player_to_move = game.perspective == game.s.player_to_move ? "me" : "opponent"
    player_score = playerscore(game.s, game.perspective)
    opponent_score = playerscore(game.s, game.perspective == 1 ? 2 : 1)
    j = Dict(
        "remaining_cards" => [card_to_name(card) for card in get_candidate_cards(game)[1]],
        "hand" => [card_to_name(card) for card in hand],
        "played_card" => card_to_name(game.s.played_card),
        "last_atout" => card_to_name(game.last_atout),
        "is_locked" => is_locked(game.s),
        "n_talon" => game.s.n_talon,
        "player_to_move" => player_to_move,
        "player_score" => player_score,
        "opponent_score" => opponent_score,
        "n_opphand" => length(opphand),
        "is_gameover" => is_gameover(game.s)
    )
    return j
end

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
    else
        incomplete_trick = ""
    end

    try
        game = game_from_str(game_string * incomplete_trick)
        println(game.s)
        return respond(json(Dict(
            "ok" => true,
            "game" => game_to_json(game)
        )))
    catch e
        @info e
        return respond(json(Dict(
            "ok" => false,
            "error" => sprint(show, e)
        )))
    end
end

@info "Start listening at localhost:8000"
up(8000, async=false)
