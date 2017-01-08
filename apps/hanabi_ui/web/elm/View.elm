module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Game
import Model
import Update


view : Model.Model Update.Msg -> Html Update.Msg
view model =
    case model.user of
        Model.Unregistered userName ->
            Html.map Update.UnregisteredMsg (viewUnregistered userName)

        Model.Registered userName playerCount ->
            Html.map
                Update.RegisteredMsg
                (viewRegistered userName playerCount model)

        Model.Playing userName ->
            Html.map Update.PlayingMsg (viewPlaying userName model)


viewUnregistered : String -> Html Update.UnregisteredMessage
viewUnregistered userName =
    Html.form [ onSubmit (Update.Register userName) ]
        [ label [ for "user_name" ]
            [ text "Name:" ]
        , input
            [ id "user_name"
            , name "user_name"
            , value userName
            , onInput Update.EnterUserName
            ]
            []
        , button [ type_ "submit" ]
            [ text "Register" ]
        ]


viewRegistered :
    String
    -> String
    -> Model.Model Update.Msg
    -> Html Update.RegisteredMessage
viewRegistered userName playerCount model =
    Html.form [ onSubmit (Update.JoinGame userName playerCount) ]
        [ p [] [ text ("Hi " ++ userName) ]
        , p []
            [ text ("Join a ")
            , select
                [ onInput Update.ChoosePlayerCount ]
                (selectOptions playerCount)
            , text (" player game.")
            ]
        , button [ type_ "submit" ] [ text "Join Game" ]
        ]


selectOptions : String -> List (Html Update.RegisteredMessage)
selectOptions playerCount =
    [ "2", "3", "4", "5" ]
        |> List.map
            (\i ->
                option [ selected (i == playerCount), value i ] [ text i ]
            )


viewPlaying : String -> Model.Model Update.Msg -> Html Update.PlayingMessage
viewPlaying userName model =
    case model.game of
        Just game ->
            Html.map Update.GameMsg (Game.view game)

        Nothing ->
            div
                []
                [ text
                    ("Waiting for more players.  "
                        ++ "Have a nice glass of water and enjoy the weather."
                    )
                ]
