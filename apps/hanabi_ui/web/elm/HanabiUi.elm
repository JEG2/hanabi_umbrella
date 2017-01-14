module HanabiUi exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Json.Encode
import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push

import Game
import Registration

main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { registration : Registration.Model
    , phxSocket : Phoenix.Socket.Socket Msg
    , game : Maybe Game.Model
    }


init : ( Model, Cmd Msg )
init =
    let
        ( phxSocket, joinCmd ) =
            initSocket
    in
        ( { registration = Registration.init
          , phxSocket = phxSocket
          , game = Nothing
          }
        , Cmd.map PhoenixMsg joinCmd
        )


initSocket : ( Phoenix.Socket.Socket Msg, Cmd (Phoenix.Socket.Msg Msg) )
initSocket =
    let
        ( lobbySocket, lobbyJoinCmd ) =
            Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
                |> Phoenix.Socket.join (Phoenix.Channel.init "game:lobby")

        ( gameSocket, gameJoinCmd ) =
            lobbySocket
                |> Phoenix.Socket.on
                    "game"
                    "game:player"
                    (\g -> AssignGame g)
                |> Phoenix.Socket.join (Phoenix.Channel.init "game:player")
    in
        ( gameSocket, Cmd.batch [ lobbyJoinCmd, gameJoinCmd ] )




-- UPDATE


type Msg
    = AssignGame Json.Encode.Value
    | GameMsg Game.Msg
    | RegistrationMsg Registration.Msg
    | PhoenixMsg (Phoenix.Socket.Msg Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AssignGame json ->
            let
                newGame =
                    json
                        |> Json.Decode.decodeValue Game.gameDecoder
                        |> Result.toMaybe
            in
                ( { model | game = newGame }, Cmd.none )

        GameMsg gameMsg ->
            updateGame gameMsg model

        RegistrationMsg registrationMsg ->
            let
                ( ( registration, phxSocket ), registrationCmd ) =
                    Registration.update
                        registrationMsg
                        ( model.registration, model.phxSocket )
                        RegistrationMsg
            in
                ( { model | registration = registration, phxSocket = phxSocket }
                , Cmd.map PhoenixMsg registrationCmd
                )

        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )


updateGame msg model =
    case msg of
        Game.Discard idx ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string (userName model) )
                        , ( "idx", Json.Encode.int idx )
                        ]

                ( phxSocket, registerCmd ) =
                    Phoenix.Push.init "discard" "game:player"
                        |> Phoenix.Push.withPayload payload
                        |> (flip Phoenix.Socket.push model.phxSocket)
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg registerCmd
                )

        Game.Play idx ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string (userName model) )
                        , ( "idx", Json.Encode.int idx )
                        ]

                ( phxSocket, registerCmd ) =
                    Phoenix.Push.init "play" "game:player"
                        |> Phoenix.Push.withPayload payload
                        |> (flip Phoenix.Socket.push model.phxSocket)
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg registerCmd
                )


userName : Model -> String
userName model =
    case model.registration of
        Registration.Complete userName -> userName
        _ -> "Unregistered"


-- VIEW


view : Model -> Html Msg
view model =
    case model.registration of
        Registration.Unregistered _ ->
            Html.map RegistrationMsg (Registration.view model.registration)

        Registration.InLobby _ _ ->
            Html.map RegistrationMsg (Registration.view model.registration)

        Registration.Complete userName ->
            viewPlaying userName model


viewPlaying : String -> Model -> Html Msg
viewPlaying userName model =
    case model.game of
        Just game ->
            Html.map GameMsg (Game.view game)

        Nothing ->
            div
                []
                [ text
                    ("Waiting for more players.  "
                        ++ "Have a nice glass of water and enjoy the weather."
                    )
                ]


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phxSocket PhoenixMsg
