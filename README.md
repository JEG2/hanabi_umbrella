# The NeverEnding Application

**Note**:  We used the game 
[Hanabi](https://boardgamegeek.com/boardgame/98778/hanabi) for demo purposes 
only.  This is a purposefully incomplete port.  We're not going to finish it.
It would make us happy if you didn't finish it either.  Please buy a copy 
instead to support the makers of great games!

## Open Questions

* Is PubSub a good fit for game events?
    * Better than using `gproc` properties?
* Should `Game.deal/0` be separate from `Game.init/0`?
    * There's a chicken-and-egg problem associating many players with one game
    * I solved this with a game ID, but there are other ways
    * Do we need a `GameMaker`?
* How we want to handle state for restarted games?
    * All moves are currently lost when a supervisor restarts a process
* Where should we use `ets`?
    * I'm leaning towards a game match up service
* How do we want the Websocket processes to find the `Game` processes?
    * `gproc` and Via Tuples
    * PubSub again
* Where do we loop in the long-term storage components?
    * They just listen on PubSub
    * `UI -> Storage -> Game`
