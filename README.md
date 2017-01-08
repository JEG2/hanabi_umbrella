# The NeverEnding Application

**Note**:  We used the game 
[Hanabi](https://boardgamegeek.com/boardgame/98778/hanabi) for demo purposes 
only.  This is a purposefully incomplete port.  We're not going to finish it.
It would make us happy if you didn't finish it either.  Please buy a copy 
instead to support the makers of great games!

## Open Questions

* Is PubSub a good fit for game events?
    * Better than using `gproc` properties?
* How we want to handle state for restarted games?
    * All moves are currently lost when a supervisor restarts a process

## To Do

* Bug:  Dual register via UI
* Better error handling
* Bug:  Race condition in subscribe/deal
* Split Elm code (user/lobby and a file per TEA)
* Split Channel lobby/games
* Fix warnings
* Add storage
* Prepare upgrade feature
* Practice and automate hot code reloading
* Handle game end?
* Draw discard pile
* Submit actions from UI
