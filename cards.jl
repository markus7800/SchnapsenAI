
struct Cards
    cs::UInt64
end

function Base.:|(left::Cards, right::Cards)::Cards
    return Cards(left.cs | right.cs)
end

function Base.:&(left::Cards, right::Cards)::Cards
    return Cards(left.cs & right.cs)
end

function Base.length(cards::Cards)
    count_ones(cards.cs)
end

struct Card
    c::UInt64
end # where only one bit set

function Base.:|(left::Card, right::Cards)::Cards
    return Cards(left.c | right.cs)
end


function Base.:|(left::Cards, right::Card)::Cards
    return Cards(left.cs | right.c)
end


function Base.in(card::Card, cards::Cards)
    card.c & cards.cs > 0
end

function remove(cards::Cards, othercards::Cards)
    Cards(cards.cs ⊻ othercards.cs)
end

function remove(cards::Cards, card::Card)
    Cards(cards.cs ⊻ card.c)
end

function add(cards::Cards, card::Card)
    Cards(cards.cs | card.c)
end

function add(cards::Cards, othercards::Cards)
    Cards(cards.cs | othercards.cs)
end

struct Face
    f::UInt
end

const CLUBS = Cards(31)                 # 0000000000000000000000000000000000000000000000000000000000011111
const SPADES = Cards(CLUBS.cs << 8)     # 0000000000000000000000000000000000000000000000000001111100000000
const DIAMONDS = Cards(SPADES.cs << 8)  # 0000000000000000000000000000000000000000000111110000000000000000
const HEARTS = Cards(DIAMONDS.cs << 8)  # 0000000000000000000000000000000000011111000000000000000000000000

function swap_suits(cards::Cards, suit1::Cards, suit2::Cards)::Cards
    l1 = trailing_zeros(suit1.cs)
    l2 = trailing_zeros(suit2.cs)

    cs = cards.cs ⊻ (cards.cs & suit1.cs)
    cs = cs ⊻ (cards.cs & suit2.cs)
    cs = cs | (((cards.cs & suit1.cs) >> l1) << l2)
    cs = cs | (((cards.cs & suit2.cs) >> l2) << l1)

    return Cards(cs)
end

const JACK = Face(2^0)
const QUEEN = Face(2^1)
const KING = Face(2^2)
const TEN = Face(2^3)
const ACE = Face(2^4)

function Base.:<(f1::Face, f2::Face)
    return f1.f < f2.f
end

function value(face::Face)
    if face == JACK
        return 2
    elseif face == QUEEN
        return 3
    elseif face == KING
        return 4
    elseif face == TEN
        return 10
    elseif face == ACE
        return 11
    else
        error("Invalid face.")
    end
end

const NOCARD = Card(0)
const NOCARDS = Cards(0)
const ALLCARDS = CLUBS | SPADES | DIAMONDS | HEARTS

function Card(suit::Cards, face::Face)::Card
    return Card(face.f << trailing_zeros(suit.cs))
end

function suit(card::Card)::Cards
    if card.c & CLUBS.cs > 0
        return CLUBS
    elseif card.c & SPADES.cs > 0
        return SPADES
    elseif card.c & DIAMONDS.cs > 0
        return DIAMONDS
    elseif card.c & HEARTS.cs > 0
        return HEARTS
    else
        return Cards(0)
    end
end

function face(card::Card)::Face
    t = trailing_zeros(card.c) ÷ 8
    return Face(card.c >> (8*t))
end

const SUIT_SYMBOLS = Dict{Cards, Char}(
    CLUBS => '♣',
    SPADES => '♠',
    DIAMONDS => '♢',
    HEARTS => '♡'
)

const FACE_SYMBOLS = Dict{Face, String}(
    JACK => "J",
    QUEEN => "Q",
    KING => "K",
    TEN => "10",
    ACE => "A"
)

# from right
function first(cards::Cards)::Card
    # trailing_zeros is Int for UInt64
    Card(1 << trailing_zeros(cards.cs))
end

function last(cards::Cards)::Card
    # trailing_zeros is Int for UInt64
    Card(1 << (64-leading_zeros(cards.cs)-1))
end

function removefirst(cards::Cards)::Cards
    Cards(cards.cs & (cards.cs - 1))
end

import Base.iterate
function Base.iterate(ss::Cards, state = ss)
    if state.cs == 0
        nothing
    else
        (first(state), removefirst(state))
    end
end


import Base.show
function show(io::IO, card::Card)
    if card == NOCARD
        print(io, "NOCARD")
    else
        s = suit(card)
        f = face(card)
        print(io, FACE_SYMBOLS[f] * SUIT_SYMBOLS[s])
    end
end

function show(io::IO, cards::Cards)
    if cards == NOCARDS
        print(io, "NOCARDS")
        return
    end

    for suit in [CLUBS, SPADES, DIAMONDS, HEARTS]
        suit_cards = Cards(suit.cs & cards.cs)
        if suit_cards != NOCARDS
            print(io, SUIT_SYMBOLS[suit])
            for card in suit_cards
                print(io, FACE_SYMBOLS[face(card)])
            end
            print(io, " ")
        end
    end
end


function all_cards()
    cards = Vector{Card}()
    for s in [CLUBS, SPADES, DIAMONDS, HEARTS]
        for f in [JACK, QUEEN, KING, TEN, ACE]
            push!(cards, Card(s, f))
        end
    end
    return cards
end
