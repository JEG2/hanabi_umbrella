module Registration
    exposing
        ( Model(..)
        , init
        , UnregisteredMessage(..)
        , InLobbyMessage(..)
        , Msg(..)
        , update
        , view
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Json.Encode
import Phoenix.Socket
import Phoenix.Push


-- MODEL


type Model
    = Unregistered String
    | InLobby String String
    | Complete String


init : Model
init =
    Unregistered ""



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


type InLobbyMessage
    = ChoosePlayerCount String
    | JoinGame String String
    | HandleJoinGameResponse Json.Encode.Value


type Msg
    = UnregisteredMsg UnregisteredMessage
    | InLobbyMsg InLobbyMessage


update :
    Msg
    -> ( Model, Phoenix.Socket.Socket msg )
    -> (Msg -> msg)
    -> ( ( Model, Phoenix.Socket.Socket msg ), Cmd (Phoenix.Socket.Msg msg) )
update msg ( model, socket ) msgMapper =
    case model of
        Unregistered userName ->
            case msg of
                UnregisteredMsg unregisteredMsg ->
                    updateUnregistered unregisteredMsg userName socket msgMapper

                InLobbyMsg _ ->
                    ( ( model, socket ), Cmd.none )

        InLobby userName playerCount ->
            case msg of
                UnregisteredMsg _ ->
                    ( ( model, socket ), Cmd.none )

                InLobbyMsg registeredMsg ->
                    updateInLobby
                        registeredMsg
                        userName
                        playerCount
                        socket
                        msgMapper

        Complete _ ->
            ( ( model, socket ), Cmd.none )


updateUnregistered :
    UnregisteredMessage
    -> String
    -> Phoenix.Socket.Socket msg
    -> (Msg -> msg)
    -> ( ( Model, Phoenix.Socket.Socket msg ), Cmd (Phoenix.Socket.Msg msg) )
updateUnregistered msg userName socket msgMapper =
    case msg of
        EnterUserName userName ->
            ( ( Unregistered userName, socket ), Cmd.none )

        Register userName ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName ) ]

                ( newSocket, registerCmd ) =
                    Phoenix.Push.init "register" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk
                            (\resp ->
                                resp
                                    |> HandleRegisterResponse
                                    |> UnregisteredMsg
                                    |> msgMapper
                            )
                        |> (flip Phoenix.Socket.push socket)
            in
                ( ( Unregistered userName, newSocket ), registerCmd )

        HandleRegisterResponse json ->
            let
                result =
                    Json.Decode.decodeValue responseDecoder json
            in
                case result of
                    Ok response ->
                        if response.success then
                            ( ( InLobby response.userName "2", socket )
                            , Cmd.none
                            )
                        else
                            ( ( Unregistered "", socket ), Cmd.none )

                    Err message ->
                        ( ( Unregistered "", socket ), Cmd.none )


updateInLobby :
    InLobbyMessage
    -> String
    -> String
    -> Phoenix.Socket.Socket msg
    -> (Msg -> msg)
    -> ( ( Model, Phoenix.Socket.Socket msg ), Cmd (Phoenix.Socket.Msg msg) )
updateInLobby msg userName playerCount socket msgMapper =
    case msg of
        ChoosePlayerCount newPlayerCount ->
            ( ( InLobby userName newPlayerCount, socket ), Cmd.none )

        JoinGame newUserName newPlayerCount ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string newUserName )
                        , ( "playerCount", Json.Encode.int (Result.withDefault 2 (String.toInt newPlayerCount)) )
                        ]

                ( newSocket, joinCmd ) =
                    Phoenix.Push.init "join" "game:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk
                            (\resp ->
                                resp
                                    |> HandleJoinGameResponse
                                    |> InLobbyMsg
                                    |> msgMapper
                            )
                        |> (flip Phoenix.Socket.push socket)
            in
                ( ( InLobby userName playerCount, newSocket )
                , joinCmd
                )

        HandleJoinGameResponse json ->
            let
                result =
                    Json.Decode.decodeValue responseDecoder json
            in
                case result of
                    Ok response ->
                        ( ( Complete response.userName, socket )
                        , Cmd.none
                        )

                    Err message ->
                        ( ( InLobby userName playerCount, socket ), Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    case model of
        Unregistered userName ->
            Html.map UnregisteredMsg (viewUnregistered userName)

        InLobby userName playerCount ->
            Html.map InLobbyMsg (viewRegistered userName playerCount model)

        Complete _ ->
            text "Registration complete."


viewUnregistered : String -> Html UnregisteredMessage
viewUnregistered userName =
    Html.form [ onSubmit (Register userName) ]
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


viewRegistered : String -> String -> Model -> Html InLobbyMessage
viewRegistered userName playerCount model =
    Html.form [ onSubmit (JoinGame userName playerCount) ]
        [ p [] [ text ("Hi " ++ userName) ]
        , p []
            [ text ("Join a ")
            , select [ onInput ChoosePlayerCount ] (selectOptions playerCount)
            , text (" player game.")
            ]
        , button [ type_ "submit" ] [ text "Join Game" ]
        ]


selectOptions : String -> List (Html InLobbyMessage)
selectOptions playerCount =
    [ "2", "3", "4", "5" ]
        |> List.map
           (\i ->
                option [ selected (i == playerCount), value i ] [ text i ]
           )
