
function showdown_pvs(s::Schnapsen, α::Int, β::Int, depth::Int)
    if depth == 0 || is_gameover(s)
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = get_moves(s)
    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), rev=true)

    if s.player_to_move == 1
        val = -1000
        for (i,m) in enumerate(ms)
            u = make_move!(s, m)
            if i == 1
                val = showdown_pvs(s, α, β, depth-1)
            else
                val = showdown_pvs(s, α, α+1, depth-1)
                if α < val < β
                    val = showdown_pvs(s, val, β, depth-1)
                end
            end

            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return α
    else
        val = 1000
        for (i,m) in enumerate(ms)
            u = make_move!(s, m)
            if i == 1
                val = showdown_pvs(s, α, β, depth-1)
            else
                val = showdown_pvs(s, β-1, β, depth-1)
                if α < val < β
                    val = showdown_pvs(s, α, val, depth-1)
                end
            end

            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return β
    end
end

s = Showdown_Schnapsen()

showdown_pvs(s, -10_000, 10_000, 2)
showdown_pvs(s, -10_000, 10_000, 4)
showdown_pvs(s, -10_000, 10_000, 6)
showdown_pvs(s, -10_000, 10_000, 8)
showdown_pvs(s, -10_000, 10_000, 10)

function pvs(s::Schnapsen, α::Int, β::Int, depth::Int)
    if is_gameover(s)
        mult = winner(s) == 1 ? 1 : -1
        return mult * winscore(s) * 1000
    end
    if depth == 0
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = get_moves(s)
    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), rev=true)

    if s.player_to_move == 1
        val = -1000
        for (i,m) in enumerate(ms)
            u = make_move!(s, m)
            if i == 1
                val = pvs(s, α, β, depth-1)
            else
                val = pvs(s, α, α+1, depth-1)
                if α < val < β
                    val = pvs(s, val, β, depth-1)
                end
            end

            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && break
        end
        return α
    else
        val = 1000
        for (i,m) in enumerate(ms)
            u = make_move!(s, m)
            if i == 1
                val = pvs(s, α, β, depth-1)
            else
                val = pvs(s, β-1, β, depth-1)
                if α < val < β
                    val = pvs(s, α, val, depth-1)
                end
            end

            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && break
        end
        return β
    end
end
