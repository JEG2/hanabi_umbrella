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
    | Registered String


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
        , Cmd.map PhoenixMsg joinCmd
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


type Msg
    = NoOp
    | EnterUserName String
    | Register String
    | HandleRegisterResponse Json.Encode.Value
    | PhoenixMsg (Phoenix.Socket.Msg Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

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
                        |> Phoenix.Push.onOk HandleRegisterResponse
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
                        ( { model | user = Registered response.userName }
                        , Cmd.none
                        )

                    Err message ->
                        ( { model | user = Unregistered "" }, Cmd.none )

        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )



-- VIEW


view : Model -> Html Msg
view model =
    case model.user of
        Unregistered userName ->
            viewUnregistered userName

        Registered userName ->
            viewRegistered userName model


viewUnregistered : String -> Html Msg
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


viewRegistered : String -> Model -> Html Msg
viewRegistered userName model =
    text "Hi!"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phxSocket PhoenixMsg
