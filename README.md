# The NeverEnding Application

This application is an experiment with alternative strategies for constructing
systems in Elixir, created for [Lonestar ElixirConf 2017](http://lonestarelixir.com/).
The design is centered around three ideas:

* Storing current state in memory
* Using append-only data storage
* Hot code reloading

Our thoughts about the results will be shared in [our presentation](http://lonestarelixir.com/speakers/#dawson).

**Note**:  We used the game 
[Hanabi](https://boardgamegeek.com/boardgame/98778/hanabi) for demo purposes
only.  This is a purposefully incomplete port.  We're not going to finish it.
It would make us happy if you didn't finish it either.  Please buy a copy 
instead to support the makers of great games!

## The Design

```
                                                  ┌──────────────────────────────────────┐
                                                  │                                      │
                                                  │                                      ▼
   ╔════════════╗                         ╔══════════════╗                          ┏━━━━━━━━━┓
   ║            ║                         ║              ║                          ┃         ┃
┌─▶║ Matchmaker ║────────────────────────▶║ Game Manager ║◀────────────────────────┐┃ Storage ┃
│  ║            ║                         ║              ║                         │┃         ┃
│  ╚════════════╝                         ╚══════════════╝                         │┗━━━━━━━━━┛
│         ▲                                       ▲                                │
│         │                                       │                                │
└─────────┼───────┐                    ┌──────────┘                                │
          └───────┼────────────────────┼──────────────────────┐                    │
                  ▼                    ▼                      │                    │
          ┌───────────────┐    ┌──────────────┐               │                    │
          │               │    │              │               ▼                    ▼
          │ Lobby Channel │    │ Game Channel │       ┌───────────────┐    ┌──────────────┐
          │               │    │              │       │               │    │              │
          └───────────────┘    └──────────────┘       │ Lobby Channel │    │ Game Channel │
                  ▲                    ▲              │               │    │              │
                  │                    │              └───────────────┘    └──────────────┘
                  │  ┌──────────────┐  │                      ▲                    ▲
                  │  │              │  │                      │                    │
                  └─▶│ Elm Frontend │◀─┘                      │  ┌──────────────┐  │
                     │              │                         │  │              │  │
                     └──────────────┘                         └─▶│ Elm Frontend │◀─┘
                                                                 │              │
                                                                 └──────────────┘
```

This repository is a umbrella application with three components:

* An in-memory game engine that handles matching up players and managing their
  games while having no knowledge of the other two components
* An add-on storage component that can save and load games from a database
* A web application the serves the UI and wires up the previous two components

### State in Memory

```
┌────────────┐                      ┌────────────────┐   ┌────────────────┐
│            │                      │                │   │                │
│ Matchmaker │                      │ Game Manager 1 │   │ Game Manager 2 │
│            │                      │                │   │                │
└────────────┘                      └────────────────┘   └────────────────┘
       │                                     │                    │
       │                                     │                    │
       │                                     │                    │
       ┼                                     ┼                    ┼
    ┏━━━━━┓                             ┏━━━━━━━━┓           ┏━━━━━━━━┓
    ┃ ets ┃                             ┃ Game 1 ┃           ┃ Game 2 ┃
    ┗━━━━━┛                             ┗━━━━━━━━┛           ┗━━━━━━━━┛
       ▲                                     ▲                    ▲
       ║                          ╔══════════╝                    ║
       ║                          ║                               ║
       ║                          ║                               ║
       ║                                                          ║
       ╚═══════════════════════ State ════════════════════════════╝
```

The current state of match ups and games in play is held in active memory via 
processes and `ets` tables.

### Long Term Storage

```
                  ┌─────────────────────────────────────────────────────────────┐
                  │                                                             │
                  │                                                             ▼
             ╔════════╗                          ╔════════╗                ┏━━━━━━━━━┓
             ║        ║                          ║        ║                ┃         ┃
     ┌───────║ Game 1 ║────────┐               ┌─║ Game 2 ║─┐              ┃ Storage ┃
     │       ║        ║        │               │ ║        ║ │              ┃         ┃
     │       ╚════════╝        │               │ ╚════════╝ │              ┗━━━━━━━━━┛
     │            │            │               │      │     │                   ▲
     │            │            │               │      │     │                   │
     │            │            │               │      └─────┼───────────────────┘
     │            │            │               │            │
     │            │            │               │            │
     │            │            │               │            │
     ▼            ▼            ▼               ▼            ▼
┌────────┐   ┌────────┐   ┌────────┐      ┌────────┐   ┌────────┐
│        │   │        │   │        │      │        │   │        │
│ User 1 │   │ User 2 │   │ User 3 │      │ User 4 │   │ User 5 │
│        │   │        │   │        │      │        │   │        │
└────────┘   └────────┘   └────────┘      └────────┘   └────────┘
```

Games communicate with players via Pub/sub.  This allows for a simple design 
where the component that saves moves into a database is just another subscriber.
Moves are saved in an append-only fashion so they can be recorded as they come
in.  Restoring a game involves replaying a series of moves.  This has pros and
cons.

On the upside, gameplay and storage are decoupled to the point that, if storage
fell behind, play could continue unaffected.  Back-pressure could be used to
keep the two concerns from getting too far separated.

However, some failure scenarios could leave the two sources of truth at
separate points in time.  Different flows of data could be used to keep things 
in sync at the cost of concurrency.  Here's one example:

```
┌──────┐       ┏━━━━━━━━━┓        ╔══════╗
│      │       ┃         ┃        ║      ║
│ User │──────▶┃ Storage ┃───────▶║ Game ║
│      │       ┃         ┃        ║      ║
└──────┘       ┗━━━━━━━━━┛        ╚══════╝
    ▲                                 │
    │                                 │
    └─────────────────────────────────┘
```

### Hot Code Reloading

To watch the code change around your in-memory game, follow these steps:

1. Checkout `master`
2. `cd apps/hanabi_ui`:
    1. `./node_modules/brunch/bin/brunch b -p`
    2. `MIX_ENV=prod mix phoenix.digest`
3. `cd ../..`:
    1. `MIX_ENV=prod mix release.clean`
    2. `MIX_ENV=prod mix release --env=prod`
    3. `PORT=4000 ./_build/prod/rel/hanabi_umbrella/bin/hanabi_umbrella foreground`
4. Play some Hanabi
5. Open a new shell:
    1. Checkout `insights_feature`
    2. `MIX_ENV=prod mix release.clean`
    3. `MIX_ENV=prod mix release --env=prod --upgrade --upfrom=0.1.0`
    4. `PORT=4000 ./_build/prod/rel/hanabi_umbrella/bin/hanabi_umbrella upgrade "0.2.0"`
6. Play more Hanabi, noting changes

### Omissions and Mistakes

* Back-pressure should be added to storage
* The end of the game isn't handled
* There's very little error handling
* The database table of games probably shouldn't be append-only
* Pub/sub was a poor choice for channel to game communication (but great for the reverse)
