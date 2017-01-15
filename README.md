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

* Prepare upgrade feature
* Practice and automate hot code reloading
* Better error handling
* Handle game end?

## Demo Steps

* Checkout `master`
* `MIX_ENV=prod mix release.clean`
* `MIX_ENV=prod mix release --env=prod`
* `PORT=4000 ./_build/prod/rel/hanabi_umbrella/bin/hanabi_umbrella foreground`
* Play some
* Open a new shell:
    * Checkout `insights_feature`
    * `MIX_ENV=prod mix release.clean`
    * `MIX_ENV=prod mix release --env=prod --upgrade --upfrom=0.1.0`
    * `PORT=4000 ./_build/prod/rel/hanabi_umbrella/bin/hanabi_umbrella upgrade "0.2.0"`
