module Game exposing(Model, gameDecoder, update, view, Msg(..))

import Dict exposing (Dict)
import Html exposing (program, text, Html, div, button)
import Html.Attributes exposing (class)
import Json.Decode as JD exposing (..)
import Json.Encode exposing (string, int)
import Phoenix.Socket
import Phoenix.Push
import Svg exposing (svg, Svg, rect, g, text, text_)
import Svg.Events exposing (onClick)
import Svg.Attributes exposing (height, width, class, x, y, rx, ry, cx, cy, r, style)


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


gameDecoder : Decoder Model
gameDecoder =
    map8 Model
        (field "clocks" JD.int)
        (field "discards" handDecoder)
        (field "draw_pile" JD.int)
        (field "fireworks" fireworkDecoder)
        (field "fuses" JD.int)
        (field "hands" (JD.dict (handDecoder)))
        (field "my_hand" handDecoder)
        (field "my_turn" JD.bool)


handDecoder : Decoder Hand
handDecoder =
    list tileDecoder


tileDecoder : Decoder Tile
tileDecoder =
    map2 (,)
        (index 0 (nullable JD.string))
        (index 1 (nullable JD.int))


fireworkDecoder : Decoder Fireworks
fireworkDecoder =
    map5 Fireworks
        (field "blue" (nullable JD.int))
        (field "green" (nullable JD.int))
        (field "red" (nullable JD.int))
        (field "white" (nullable JD.int))
        (field "yellow" (nullable JD.int))


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type Msg
    = Discard Int
    | Play Int


update :
    Msg
    -> String
    -> ( Model, Phoenix.Socket.Socket msg )
    -> (Msg -> msg)
    -> ( ( Model, Phoenix.Socket.Socket msg ), Cmd (Phoenix.Socket.Msg msg) )
update msg userName ( model, socket ) msgMapper =
    case msg of
        Discard idx ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName )
                        , ( "idx", Json.Encode.int idx )
                        ]

                ( newSocket, gameCmd ) =
                    Phoenix.Push.init "discard" "game:player"
                        |> Phoenix.Push.withPayload payload
                        |> (flip Phoenix.Socket.push socket)
            in
                ( ( model, newSocket ), gameCmd )

        Play idx ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName )
                        , ( "idx", Json.Encode.int idx )
                        ]

                ( newSocket, gameCmd ) =
                    Phoenix.Push.init "play" "game:player"
                        |> Phoenix.Push.withPayload payload
                        |> (flip Phoenix.Socket.push socket)
            in
                ( ( model, newSocket ), gameCmd )


view : Model -> Html Msg
view model =
    div [ ] [ div [ Html.Attributes.class "draw"] [ Html.text ("Remaining Tiles: " ++ toString model.draw_pile)]
            , div [ Html.Attributes.class "fuses"] [ Html.text ("Fuses: " ++ toString model.fuses)]
            , div [ Html.Attributes.class "timers"] [ Html.text ("Clocks: " ++ toString model.clocks)]
            , div [ Html.Attributes.class "turn"] [ Html.text ("My Turn: " ++ toString model.my_turn)]
            , div [ Html.Attributes.class "fireworks"]
                  [ renderFireworkPile model.fireworks (100,60,10)]
            , div [ Html.Attributes.class "player-container" ]
                  [ renderPlayerHand model.my_hand (100,60,15) "player" model.my_turn]
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
renderDiscardPile hand (width,height,padding) =
    div [] [ div [] [Html.text ("Discards:") ]
           , Svg.svg [ Svg.Attributes.height (handHeight height padding)
                     , Svg.Attributes.width (handWidth width padding)
                     , Svg.Attributes.class ("discards") ]
                     (List.indexedMap (drawTile (width,height,padding)) hand)]


renderTeamHands : Dict String Hand -> (Int, Int, Int) -> List (Svg a)
renderTeamHands hands dimensions =
    hands
        |> Dict.map (renderTeamHand dimensions)
        |> Dict.values


renderTeamHand : (Int, Int, Int) -> String -> Hand -> Svg a
renderTeamHand (width, height, padding) name hand =
    div [] [ div [] [Html.text (name ++ "'s hand:") ]
           , Svg.svg [ Svg.Attributes.height (handHeight height padding)
                     , Svg.Attributes.width (handWidth width padding)
                     , Svg.Attributes.class (name ++ "-hand") ]
                     (List.indexedMap (drawTile (width,height,padding)) hand)]


renderPlayerHand : Hand -> (Int, Int, Int) -> String -> Bool -> Html Msg
renderPlayerHand hand (width, height, padding) name  my_turn =
    div [] [ Svg.svg [ Svg.Attributes.height (handHeight height padding)
                     , Svg.Attributes.width (handWidth width padding)
                     , Svg.Attributes.class (name ++ "-hand") ]
                     (List.indexedMap (drawPlayerTile (width,height,padding) my_turn) hand)]


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


drawPlayerTile : (Int, Int, Int) -> Bool -> Int -> Tile -> Svg Msg
drawPlayerTile (w, h, padding) my_turn idx (color, number) =
    let
        xpos = tileXpos w padding idx
        ypos = padding
    in
        case my_turn of
            True ->
                g [] [ (rect [ width (toString w)
                             , height (toString h)
                             , y (toString ypos)
                             , x (toString xpos)
                             , rx "10" --("toString padding)
                             , ry "10" -- (toString padding)
                             ] [])
                     , renderFirework xpos ypos (color, number)
                     , discardButton xpos ypos idx
                     , playButton xpos ypos idx
                     ]

            False ->
                g [] [ (rect [ width (toString w)
                             , height (toString h)
                             , y (toString ypos)
                             , x (toString xpos)
                             , rx "10" --("toString padding)
                             , ry "10" -- (toString padding)
                             ] [])
                     , renderFirework xpos ypos (color, number)
                     ]



discardButton : Int -> Int -> Int -> Svg Msg
discardButton xpos ypos idx =
    Svg.text_ [ x (toString xpos), y (toString ypos), onClick (Discard idx)] [ (Svg.text "Discard") ]

playButton : Int -> Int -> Int -> Svg Msg
playButton xpos ypos idx =
    Svg.text_ [ x (toString (xpos + 75)), y (toString ypos), onClick (Play idx)] [ (Svg.text "Play") ]


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
