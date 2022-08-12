# SchnapsenAI

Schnapsen engine.

Information about game [here](https://en.wikipedia.org/wiki/Schnapsen).

## How it works

Replace unknown cards through sampling.
Perform AlphaBeta with open cards.
Compute aggregate statistics over all possible unknown cards.

## How to run
```
pkg> activate .
pkg> instantiate
```

Adjust number of threads to match number of cores.
```
julia --project=. --threads=20 start_ui.jl
```
