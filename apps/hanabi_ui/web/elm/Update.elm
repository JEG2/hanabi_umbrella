module Update
    exposing
        ( UnregisteredMessage(..)
        , RegisteredMessage(..)
        , SharedMessage(..)
        , PlayingMessage(..)
        , Msg(..)
        , update
        )

import Json.Decode
import Json.Encode
import Phoenix.Push
import Phoenix.Socket
import Model
import Game


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


type PlayingMessage
    = AssignGame Json.Encode.Value
    | GameMsg Game.Msg


type Msg
    = UnregisteredMsg UnregisteredMessage
    | RegisteredMsg RegisteredMessage
    | SharedMsg SharedMessage
    | PlayingMsg PlayingMessage


update : Msg -> Model.Model Msg -> ( Model.Model Msg, Cmd Msg )
update msg model =
    case model.user of
        Model.Unregistered userName ->
            case msg of
                UnregisteredMsg unregisteredMsg ->
                    let
                        ( newModel, sharedMessage ) =
                            updateUnregistered unregisteredMsg userName model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )

                RegisteredMsg _ ->
                    ( model, Cmd.none )

                PlayingMsg _ ->
                    ( model, Cmd.none )

                SharedMsg sharedmsg ->
                    let
                        ( newModel, sharedMessage ) =
                            updateShared sharedmsg model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )

        Model.Registered userName playerCount ->
            case msg of
                UnregisteredMsg _ ->
                    ( model, Cmd.none )

                PlayingMsg _ ->
                    ( model, Cmd.none )

                RegisteredMsg registeredMsg ->
                    let
                        ( newModel, sharedMessage ) =
                            updateRegistered
                                registeredMsg
                                userName
                                playerCount
                                model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )

                SharedMsg sharedmsg ->
                    let
                        ( newModel, sharedMessage ) =
                            updateShared sharedmsg model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )

        Model.Playing userName ->
            case msg of
                UnregisteredMsg _ ->
                    ( model, Cmd.none )

                RegisteredMsg _ ->
                    ( model, Cmd.none )

                PlayingMsg playingMessage ->
                    let
                        ( newModel, sharedMessage ) =
                            updatePlaying playingMessage userName model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )

                SharedMsg sharedmsg ->
                    let
                        ( newModel, sharedMessage ) =
                            updateShared sharedmsg model
                    in
                        ( newModel, Cmd.map SharedMsg sharedMessage )


updateShared :
    SharedMessage
    -> Model.Model Msg
    -> ( Model.Model Msg, Cmd SharedMessage )
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


updateUnregistered :
    UnregisteredMessage
    -> String
    -> Model.Model Msg
    -> ( Model.Model Msg, Cmd SharedMessage )
updateUnregistered msg userName model =
    case msg of
        EnterUserName userName ->
            ( { model | user = Model.Unregistered userName }, Cmd.none )

        Register userName ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName ) ]

                ( phxSocket, registerCmd ) =
                    Phoenix.Push.init "register" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk
                            (\resp ->
                                UnregisteredMsg (HandleRegisterResponse resp)
                            )
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
                        ( { model
                            | user = Model.Registered response.userName "2"
                          }
                        , Cmd.none
                        )

                    Err message ->
                        ( { model | user = Model.Unregistered "" }, Cmd.none )


updateRegistered :
    RegisteredMessage
    -> String
    -> String
    -> Model.Model Msg
    -> ( Model.Model Msg, Cmd SharedMessage )
updateRegistered msg userName playerCount model =
    case msg of
        ChoosePlayerCount newPlayerCount ->
            ( { model | user = Model.Registered userName newPlayerCount }
            , Cmd.none
            )

        JoinGame newUserName newPlayerCount ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string newUserName )
                        , ( "playerCount", Json.Encode.string newPlayerCount )
                        ]

                ( phxSocket, joinCmd ) =
                    Phoenix.Push.init "join" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk
                            (\resp ->
                                RegisteredMsg (HandleJoinGameResponse resp)
                            )
                        |> (flip Phoenix.Socket.push model.phxSocket)
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg joinCmd
                )

        HandleJoinGameResponse json ->
            let
                result =
                    Json.Decode.decodeValue responseDecoder json
            in
                case result of
                    Ok response ->
                        ( { model | user = Model.Playing response.userName }
                        , Cmd.none
                        )

                    Err message ->
                        ( model, Cmd.none )


updatePlaying :
    PlayingMessage
    -> String
    -> Model.Model Msg
    -> ( Model.Model Msg, Cmd SharedMessage )
updatePlaying msg userName model =
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
            ( model, Cmd.none )
