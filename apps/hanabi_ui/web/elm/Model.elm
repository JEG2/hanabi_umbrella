module Model exposing (User(..), Model)

import Game
import Phoenix.Socket

type User
    = Unregistered String
    | Registered String String
    | Playing String


type alias Model msg =
    { user : User
    , phxSocket : Phoenix.Socket.Socket msg
    , game : Maybe Game.Model
    }
