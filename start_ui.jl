
using Genie

import Genie.Router: route
import Genie.Renderer: respond
import JSON: json

include("game2.jl")

game_string = ""
move1 = "*"
move2 = "*"
drawncard = "*"
game = Game(0)

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
        "remaining_cards" => [card_to_name(card) for card in get_candidate_cards(game, player=game.perspective)[1]],
        "hand" => [card_to_name(card) for card in hand],
        "played_card" => card_to_name(game.s.played_card),
        "last_atout" => card_to_name(game.last_atout),
        "is_locked" => is_locked(game.s),
        "n_talon" => game.s.n_talon,
        "next" => player_to_move,
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
    global move1
    global move2
    global drawncard
    global game

    game_string = ""
    move1 = "*"
    move2 = "*"
    drawncard = "*"
    game = Game(0)

    hand = params(:hand)
    lastatout = params(:atout)
    oppmove = params(:oppmove)
    lock = parse(Bool, params(:lock))
    call = parse(Bool, params(:call))
    swap = parse(Bool, params(:swap))

    @info "/newgame" hand lastatout oppmove lock call swap

    perspective = oppmove == "" ? "1" : "2"

    game_string = hand * " - " * perspective * " - " * lastatout * " - "
    if oppmove != ""
        move1 = oppmove
        if (lock || call || swap)
            move1 *= " "
        end
        if lock
            move1 *= "z"
        end
        if call
            move1 *= "a"
        end
        if swap
            move1 *= "t"
        end

        incomplete_trick = move1 * " : * : *"
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

route("/engine") do
    global game
    @info "/engine"
    println(game)
    println(game.s)

    if game.perspective != game.s.player_to_move
        return respond(json(Dict(
            "ok" => false,
            "error" => "Not your move."
        )))
    end

    move, prob = get_best_move(game)

    card = card_to_name(move.card)
    @info "Best move: " card move.lock move.call move.swap

    return respond(json(Dict(
        "ok" => true,
        "card" => card,
        "lock" => move.lock,
        "call" => move.call,
        "swap" => move.swap,
        "losing_probability" => prob
    )))
end

function make_game_move()
    global game_string
    global move1
    global move2
    global drawncard
    global game

    s = move1 * " : " * move2 * " : " * drawncard

    game = game_from_str(game_string * s)

    if move1 != "*" && move2 != "*"
        game_string *= s * " #\n"

        println(game_string)
        println(game)

        move1 = "*"
        move2 = "*"
        drawncard = "*"
    end
end

route("/mymove") do
    global move1
    global move2
    global game

    card = params(:card)
    lock = parse(Bool, params(:lock))
    call = parse(Bool, params(:call))
    swap = parse(Bool, params(:swap))

    @info "/mymove" card lock swap call

    move = card
    if (lock || call || swap)
        move *= " "
    end
    if lock
        move *= "z"
    end
    if call
        move *= "a"
    end
    if swap
        move *= "t"
    end
    if game.perspective == 1
        move1 = move
    else
        move2 = move
    end

    draw_card = !is_locked(game.s) && game.s.n_talon > 0 && move1 != "*" && move2 != "*"

    if draw_card
        game_json = game_to_json(game)
        game_json["next"] = "drawcard"
        return respond(json(Dict(
            "ok" => true,
            "game" => game_json
        )))
    else
        try
            make_game_move()
            return respond(json(Dict(
                "ok" => true,
                "game" => game_to_json(game)
            )))
        catch e
            return respond(json(Dict(
                "ok" => false,
                "error" => sprint(show, e)
            )))
        end
    end
end

route("/drawcard") do
    global drawncard
    card = params(:card)

    @info "/drawcard" card

    drawncard = card

    try
        make_game_move()
        return respond(json(Dict(
            "ok" => true,
            "game" => game_to_json(game)
        )))
    catch e
        return respond(json(Dict(
            "ok" => false,
            "error" => sprint(show, e)
        )))
    end
end

route("/oppmove") do
    global move1
    global move2
    global game

    card = params(:card)
    lock = parse(Bool, params(:lock))
    call = parse(Bool, params(:call))
    swap = parse(Bool, params(:swap))


    move = card
    if (lock || call || swap)
        move *= " "
    end
    if lock
        move *= "z"
    end
    if call
        move *= "a"
    end
    if swap
        move *= "t"
    end
    if game.perspective == 1
        move2 = move
    else
        move1 = move
    end

    draw_card = !is_locked(game.s) && game.s.n_talon > 0 && move1 != "*" && move2 != "*"

    if draw_card
        game_json = game_to_json(game)
        game_json["next"] = "drawcard"
        return respond(json(Dict(
            "ok" => true,
            "game" => game_json
        )))
    else
        try
            make_game_move()
            return respond(json(Dict(
                "ok" => true,
                "game" => game_to_json(game)
            )))
        catch e
            return respond(json(Dict(
                "ok" => false,
                "error" => sprint(show, e)
            )))
        end
    end
end

@info "Start listening at localhost:8000"
up(8000, async=false)

‚
