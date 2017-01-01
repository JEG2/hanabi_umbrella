module HanabiUi exposing(main)

import Html exposing (program, text, Html, div)
import Json.Decode exposing (..)
import Dict exposing (Dict)
import Html.Attributes exposing(class)


main =
  Html.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


type Msg
    = NoOp


type alias Tile = (Maybe String, Maybe Int)
type alias Hand = List Tile
type alias Fireworks =
    { blue : Maybe Int
    , green : Maybe Int
    , red : Maybe Int
    , white : Maybe Int
    , yellow : Maybe Int
    }
type alias Model =
    { clocks : Int
    , discards : List Tile
    , draw_pile : Int
    , fireworks : Fireworks
    , fuses : Int
    , hands : Dict String Hand
    , my_hand : Hand
    , my_turn : Bool
    }


init : Value -> (Model, Cmd Msg)
init values =
    values
        |> decodeValue gameDecoder
        |> Result.withDefault defaultModel
        |> (,)
         <| Cmd.none


defaultModel : Model
defaultModel =
    { clocks = 0
    , discards = []
    , draw_pile = 0
    , fireworks = {blue = Nothing, green = Nothing, red = Nothing, white = Nothing, yellow = Nothing}
    , fuses = 0
    , hands = Dict.fromList [("Jon", [])]
    , my_hand = [(Nothing, Nothing), (Nothing, Nothing), (Nothing, Nothing), (Nothing, Nothing)]
    , my_turn = False}


gameDecoder : Decoder Model
gameDecoder =
    map8 Model
        (field "clocks" int)
        (field "discards" handDecoder)
        (field "draw_pile" int)
        (field "fireworks" fireworkDecoder)
        (field "fuses" int)
        (field "hands" (dict (handDecoder)))
        (field "my_hand" handDecoder)
        (field "my_turn" bool)


handDecoder : Decoder Hand
handDecoder =
    list tileDecoder


tileDecoder : Decoder Tile
tileDecoder =
    map2 (,)
        (index 0 (nullable string))
        (index 1 (nullable int))


fireworkDecoder : Decoder Fireworks
fireworkDecoder =
    map5 Fireworks
        (field "blue" (nullable int))
        (field "green" (nullable int))
        (field "red" (nullable int))
        (field "white" (nullable int))
        (field "yellow" (nullable int))


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    (model, Cmd.none)


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ text "hello elmland" ]
