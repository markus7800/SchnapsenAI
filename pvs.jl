
mutable struct PVS
    depth::Int
    mls::Vector{MoveList}
    uls::Vector{Undo}
    n_nodes::Int
    function PVS(depth::Int)
        return new(
            depth,
            [MoveList() for _ in 1:20],
            [Undo() for _ in 1:20],
            0,
        )
    end
end

function go(pvs::PVS, s::Schnapsen)::Int
    return pvs!(pvs, s, -10_000, 10_000, pvs.depth)
end

function pvs!(pvs::PVS, s::Schnapsen, α::Int, β::Int, depth::Int)::Int
    pvs.n_nodes += 1
    if is_gameover(s)
        mult = winner(s) == 1 ? 1 : -1
        return mult * winscore(s) * 1000
    end
    if depth == 0
        return playerscore(s, 1) - playerscore(s, 2)
    end

    ms = pvs.mls[depth]
    recycle!(ms)
    get_moves!(ms, s)
    u = pvs.uls[depth]

    sort!(ms, lt=(x,y) -> move_value(s,x) < move_value(s,y), alg=Base.Sort.QuickSort, rev=true)

    if s.player_to_move == 1
        # val = -10_000
        for (i, m) in enumerate(ms)
            make_move!(s, m, u)
            if i == 1
                val = pvs!(pvs, s, α, β, depth-1)
            else
                val = pvs!(pvs, s, α, α+1, depth-1)
                if α < val < β
                    #val = pvs!(pvs, s, val, β, depth-1)
                    val = pvs!(pvs, s, α, β, depth-1)
                end
            end
            undo_move!(s, m, u)
            α = max(α, val)
            α ≥ β && return β
        end
        return α
    else
        #val = 10_000
        for (i,m) in enumerate(ms)
            make_move!(s, m, u)
            if i == 1
                val = pvs!(pvs, s, α, β, depth-1) # TODO: here min or not?
                #val = min(val, pvs!(pvs, s, α, β, depth-1)) # TODO: here min or not?
            else
                val = pvs!(pvs, s, β-1, β, depth-1)
                if α < val < β
                    #val = pvs!(s, α, val, depth-1)
                    val = pvs!(pvs, s, α, β, depth-1)
                end
            end
            undo_move!(s, m, u)
            β = min(β, val)
            β ≤ α && return α
        end
        return β
    end
end
