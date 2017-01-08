module Game exposing(Model, gameDecoder, view, Msg)

import Html exposing (program, text, Html, div)
import Json.Decode exposing (..)
import Dict exposing (Dict)
import Html.Attributes exposing (class)
import Svg exposing (svg, Svg, rect, g)
import Svg.Attributes exposing (height, width, class, x, y, rx, ry, cx, cy, r, style)


-- main =
--   Html.programWithFlags
--     { init = init
--     , view = view
--     , update = update
--     , subscriptions = subscriptions
--     }


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
    (values
        |> decodeValue gameDecoder
        |> Result.withDefault defaultModel
        |> (,))
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
    div [ ] [ div [ Html.Attributes.class "draw"] [ text ("Remaining Tiles: " ++ toString model.draw_pile)]
            , div [ Html.Attributes.class "fuses"] [ text ("Fuses: " ++ toString model.fuses)]
            , div [ Html.Attributes.class "timers"] [ text ("Clocks: " ++ toString model.clocks)]
            , div [ Html.Attributes.class "fireworks"]
                  [ renderFireworkPile model.fireworks (100,60,10)]
            , div [ Html.Attributes.class "player-container" ]
                  [ renderPlayerHand model.my_hand (100,60,10) "player" ]
            , div [ Html.Attributes.class "team-container" ]
                  (renderTeamHands model.hands (100,60,10))
            , div [ Html.Attributes.class "discards-container" ]
                  [ renderDiscardPile model.discards (100,60,10) ]
            ]


renderFireworkPile : Fireworks -> (Int, Int, Int) -> Svg a
renderFireworkPile fireworks (w,h,padding) =
    Svg.svg [ Svg.Attributes.height (toString ((h + padding) * 5 + padding))
            , Svg.Attributes.width (toString (padding + w + padding)) ]
            [ (drawFireworkTile (w,h,padding) 0 (Just "blue", fireworks.blue))
            , (drawFireworkTile (w,h,padding) 1 (Just "green", fireworks.green))
            , (drawFireworkTile (w,h,padding) 2 (Just "red", fireworks.red))
            , (drawFireworkTile (w,h,padding) 3 (Just "white", fireworks.white))
            , (drawFireworkTile (w,h,padding) 4 (Just "yellow", fireworks.yellow)) ]


drawFireworkTile : (Int, Int, Int) -> Int -> Tile -> Svg a
drawFireworkTile (w, h, padding) idx (color, number) =
    let
        xpos = padding
        ypos = tileXpos h padding idx
        fillStyle =
            case number of
                Just num -> ""
                Nothing -> "fill-opacity:0.1"
    in
        g [] [(rect [ width (toString w)
                    , height (toString h)
                    , y (toString ypos)
                    , x (toString xpos)
                    , rx (toString padding)
                    , ry (toString padding)
                    , style fillStyle
                    ] [])
             , renderFirework xpos ypos (color, number)
             ]


renderDiscardPile : Hand -> (Int, Int, Int) -> Svg a
renderDiscardPile hand dimensions =
    g [ ] [ ]


renderTeamHands : Dict String Hand -> (Int, Int, Int) -> List (Svg a)
renderTeamHands hands dimensions =
    hands
        |> Dict.map (teamHand dimensions)
        |> Dict.values


teamHand : (Int, Int, Int) -> String -> Hand -> Svg a
teamHand dimensions name hand =
    renderPlayerHand hand dimensions name


renderPlayerHand : Hand -> (Int, Int, Int) -> String -> Svg a
renderPlayerHand hand (width, height, padding) name  =
    Svg.svg [ Svg.Attributes.height (handHeight height padding)
            , Svg.Attributes.width (handWidth width padding)
            , Svg.Attributes.class (name ++ "-hand") ]
            (List.indexedMap (drawTile (width,height,padding)) hand)


handHeight : Int -> Int -> String
handHeight height padding =
    (padding + height + padding)
        |> toString


handWidth : Int -> Int -> String
handWidth width padding =
    ((padding + width) * 5) + padding
        |> toString


drawTile : (Int, Int, Int) -> Int -> Tile -> Svg a
drawTile (w, h, padding) idx (color, number) =
    let
        xpos = tileXpos w padding idx
        ypos = padding
    in
        g [] [(rect [ width (toString w)
                    , height (toString h)
                    , y (toString ypos)
                    , x (toString xpos)
                    , rx (toString padding)
                    , ry (toString padding)
                    ] [])
             , renderFirework xpos ypos (color, number)
             ]


tileXpos : Int -> Int -> Int -> Int
tileXpos w padding idx =
    padding + (idx * w) + (idx * padding)


renderFirework : Int -> Int -> Tile -> Svg a
renderFirework xpos ypos (color, number) =
    case (Maybe.withDefault 0 number) of
        1 -> renderOne xpos ypos color
        2 -> renderTwo xpos ypos color
        3 -> renderThree xpos ypos color
        4 -> renderFour xpos ypos color
        5 -> renderFive xpos ypos color
        _ -> g [] []


renderOne : Int -> Int -> Maybe String -> Svg a
renderOne xpos ypos color =
    g [ ]
      [ (Svg.circle [ cx (toString (xpos + 20))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] [])
      ]


renderTwo : Int -> Int -> Maybe String -> Svg a
renderTwo xpos ypos color =
    g [ ]
      [ (Svg.circle [ cx (toString (xpos + 30))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] [])
      ]


renderThree : Int -> Int -> Maybe String -> Svg a
renderThree xpos ypos color =
    g [ ]
      [ (Svg.circle [ cx (toString (xpos + 30))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 70))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] [])

      ]


renderFour : Int -> Int -> Maybe String -> Svg a
renderFour xpos ypos color =
    g [ ]
      [ (Svg.circle [ cx (toString (xpos + 30))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 70))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 40))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] [])
      ]


renderFive : Int -> Int -> Maybe String -> Svg a
renderFive xpos ypos color =
    g [ ]
      [ (Svg.circle [ cx (toString (xpos + 30))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 70))
                    , cy (toString (ypos + 20))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 50))
                    , cy (toString (ypos + 40))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] []),
        (Svg.circle [ cx (toString (xpos + 30))
                    , cy (toString (ypos + 40))
                    , r "5"
                    , style ("fill: " ++ (Maybe.withDefault "black" color))
                    ] [])

      ]
