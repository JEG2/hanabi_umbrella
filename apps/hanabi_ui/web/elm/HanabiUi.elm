module HanabiUi exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Json.Encode
import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type User
    = Unregistered String
    | Registered String String
    | Waiting String


type alias Model =
    { user : User
    , phxSocket : Phoenix.Socket.Socket Msg
    }


init : ( Model, Cmd Msg )
init =
    let
        ( phxSocket, joinCmd ) =
            initSocket
    in
        ( { user = Unregistered ""
          , phxSocket = phxSocket
          }
        , Cmd.map SharedMsg (Cmd.map PhoenixMsg joinCmd)
        )


initSocket : ( Phoenix.Socket.Socket Msg, Cmd (Phoenix.Socket.Msg Msg) )
initSocket =
    Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
        |> Phoenix.Socket.join (Phoenix.Channel.init "game:lobby")



-- UPDATE


type alias Response =
    { success : Bool
    , userName : String
    , message : String
    }


responseDecoder : Json.Decode.Decoder Response
responseDecoder =
    Json.Decode.map3 Response
        (Json.Decode.field "success" Json.Decode.bool)
        (Json.Decode.field "userName" Json.Decode.string)
        (Json.Decode.field "message" Json.Decode.string)


type UnregisteredMessage
    = EnterUserName String
    | Register String
    | HandleRegisterResponse Json.Encode.Value


type RegisteredMessage
    = ChoosePlayerCount String
    | JoinGame String String
    | HandleJoinGameResponse Json.Encode.Value


type SharedMessage
    = PhoenixMsg (Phoenix.Socket.Msg Msg)


type Msg
    = UnregisteredMsg UnregisteredMessage
    | RegisteredMsg RegisteredMessage
    | SharedMsg SharedMessage


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model.user of
        Unregistered userName ->
            case msg of
                UnregisteredMsg unregisteredMsg ->
                    let
                        (newModel, sharedMessage) = updateUnregistered unregisteredMsg userName model
                    in
                        (newModel, Cmd.map SharedMsg sharedMessage)

                RegisteredMsg _ -> (model, Cmd.none)

                SharedMsg sharedmsg ->
                    let
                        (newModel, sharedMessage) = updateShared sharedmsg model
                    in
                        (newModel, Cmd.map SharedMsg sharedMessage)


        Registered userName playerCount ->
            case msg of
                UnregisteredMsg _  -> (model, Cmd.none)

                RegisteredMsg registeredMsg ->
                    let
                        (newModel, sharedMessage) = updateRegistered registeredMsg userName playerCount model
                    in
                        (newModel, Cmd.map SharedMsg sharedMessage)

                SharedMsg sharedmsg ->
                    let
                        (newModel, sharedMessage) = updateShared sharedmsg model
                    in
                        (newModel, Cmd.map SharedMsg sharedMessage)

        Waiting userName ->
            case msg of
                UnregisteredMsg _  -> (model, Cmd.none)

                RegisteredMsg _ -> (model, Cmd.none)

                SharedMsg sharedmsg ->
                    let
                        (newModel, sharedMessage) = updateShared sharedmsg model
                    in
                        (newModel, Cmd.map SharedMsg sharedMessage)


updateShared : SharedMessage -> Model -> (Model, Cmd SharedMessage)
updateShared msg model =
    case msg of
        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )



updateUnregistered : UnregisteredMessage -> String -> Model -> (Model, Cmd SharedMessage)
updateUnregistered msg userName model =
    case msg of
        EnterUserName userName ->
            ( { model | user = Unregistered userName }, Cmd.none )

        Register userName ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName ) ]

                ( phxSocket, registerCmd ) =
                    Phoenix.Push.init "register" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk (\resp -> UnregisteredMsg (HandleRegisterResponse resp))
                        |> (flip Phoenix.Socket.push model.phxSocket)
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg registerCmd
                )

        HandleRegisterResponse json ->
            let
                result =
                    Json.Decode.decodeValue responseDecoder json
            in
                case result of
                    Ok response ->
                        ( { model | user = Registered response.userName "2" }
                        , Cmd.none
                        )

                    Err message ->
                        ( { model | user = Unregistered "" }, Cmd.none )



updateRegistered : RegisteredMessage -> String -> String -> Model -> (Model, Cmd SharedMessage)
updateRegistered msg userName playerCount model =
    case msg of
        ChoosePlayerCount newPlayerCount ->
            ({model | user = Registered userName newPlayerCount}, Cmd.none)
        JoinGame newUserName newPlayerCount ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string newUserName )
                        , ( "playerCount", Json.Encode.string newPlayerCount )
                        ]

                ( phxSocket, registerCmd ) =
                    Phoenix.Push.init "join" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk (\resp -> RegisteredMsg (HandleJoinGameResponse resp))
                        |> (flip Phoenix.Socket.push model.phxSocket)
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg registerCmd
                )

        HandleJoinGameResponse json ->
            let
                result =
                    Json.Decode.decodeValue responseDecoder json
            in
                case result of
                    Ok response ->
                        ( { model | user = Waiting response.userName }, Cmd.none )

                    Err message ->
                        ( model, Cmd.none )

-- VIEW


view : Model -> Html Msg
view model =
    case model.user of
        Unregistered userName ->
            Html.map UnregisteredMsg (viewUnregistered userName)

        Registered userName playerCount ->
            Html.map RegisteredMsg (viewRegistered userName playerCount model)

        Waiting userName ->
            viewWaiting userName model


viewUnregistered : String -> Html UnregisteredMessage
viewUnregistered userName =
    Html.form [ onSubmit (Register userName)]
        [ label [ for "user_name" ]
            [ text "Name:" ]
        , input
            [ id "user_name"
            , name "user_name"
            , value userName
            , onInput EnterUserName
            ]
            []
        , button [ type_ "submit" ]
            [ text "Register" ]
        ]


viewRegistered : String -> String -> Model -> Html RegisteredMessage
viewRegistered userName playerCount model =
    Html.form [ onSubmit (JoinGame userName playerCount)]
        [ p [ ] [ text ("Hi " ++ userName) ]
        , p [ ] [ text ("Join a ")
                , select [ onInput ChoosePlayerCount ] (selectOptions playerCount)
                , text (" player game.") ]
        , button [ type_ "submit" ] [ text "Join Game"]]


selectOptions : String -> List (Html RegisteredMessage)
selectOptions playerCount =
    ["2", "3", "4", "5"]
        |> List.map (\i -> option [selected (i == playerCount), value i] [text i])


viewWaiting : String -> Model -> Html Msg
viewWaiting userName model =
    div [ ] [ text "Waiting for more players. Have a nice glass of water and enjoy the weather." ]

-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phxSocket (\msg -> SharedMsg (PhoenixMsg msg))
