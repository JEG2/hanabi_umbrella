module HanabiUi exposing (main)

import Html exposing (..)
import Phoenix.Channel
import Phoenix.Socket
import Model
import Update
import View


main : Program Never (Model.Model Update.Msg) Update.Msg
main =
    Html.program
        { init = init
        , view = View.view
        , update = Update.update
        , subscriptions = subscriptions
        }


init : ( Model.Model Update.Msg, Cmd Update.Msg )
init =
    let
        ( phxSocket, joinCmd ) =
            initSocket
    in
        ( { user = Model.Unregistered ""
          , phxSocket = phxSocket
          , game = Nothing
          }
        , Cmd.map Update.SharedMsg (Cmd.map Update.PhoenixMsg joinCmd)
        )


initSocket : ( Phoenix.Socket.Socket Update.Msg, Cmd (Phoenix.Socket.Msg Update.Msg) )
initSocket =
    Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
        |> Phoenix.Socket.on
            "game"
            "game:lobby"
            (\g -> Update.PlayingMsg (Update.AssignGame g))
        |> Phoenix.Socket.join (Phoenix.Channel.init "game:lobby")


subscriptions : Model.Model Update.Msg -> Sub Update.Msg
subscriptions model =
    Phoenix.Socket.listen
        model.phxSocket
        (\msg -> Update.SharedMsg (Update.PhoenixMsg msg))
