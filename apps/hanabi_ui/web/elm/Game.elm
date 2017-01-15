module Game exposing (Model, gameDecoder, update, view, Msg(..))

import Dict exposing (Dict)
import Html exposing (program, text, Html, div, button)
import Html.Attributes exposing (class)
import Json.Decode as JD exposing (..)
import Json.Encode exposing (string, int)
import Phoenix.Socket
import Phoenix.Push
import Svg exposing (svg, Svg, rect, g, text, text_)
import Svg.Events exposing (onClick)
import Set exposing (fromList, toList)
import Svg.Attributes
    exposing
        ( height
        , width
        , class
        , x
        , y
        , rx
        , ry
        , cx
        , cy
        , r
        , style
        )


-- MODEL


type alias Tile =
    ( Maybe String, Maybe Int )


type alias Hand =
    List Tile


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
    , my_data : MyData
    }


type alias MyData =
    { hand : Hand
    , turn : Bool
    , insights : Maybe (List (List String))
    }


gameDecoder : Decoder Model
gameDecoder =
    map7 Model
        (field "clocks" JD.int)
        (field "discards" handDecoder)
        (field "draw_pile" JD.int)
        (field "fireworks" fireworkDecoder)
        (field "fuses" JD.int)
        (field "hands" (JD.dict handDecoder))
        (field "my_data" myDataDecoder)


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


myDataDecoder : Decoder MyData
myDataDecoder =
    map3 MyData
        (field "hand" handDecoder)
        (field "turn" JD.bool)
        (maybe (field "insights" insightsDecoder))


insightsDecoder : Decoder (List (List String))
insightsDecoder =
    JD.list (JD.list JD.string)



-- UPDATE


type Msg
    = Discard Int
    | Play Int
    | Hint String String


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

        Hint name hint ->
            let
                payload =
                    Json.Encode.object
                        [ ( "userName", Json.Encode.string userName )
                        , ( "name", Json.Encode.string name )
                        , ( "hint", Json.Encode.string hint )
                        ]

                ( newSocket, gameCmd ) =
                    Phoenix.Push.init "hint" "game:player"
                        |> Phoenix.Push.withPayload payload
                        |> (flip Phoenix.Socket.push socket)
            in
                ( ( model, newSocket ), gameCmd )



-- VIEW


view : Model -> Html Msg
view model =
    div [ Html.Attributes.class "game-container" ]
        [ (gameDetails model)
        , (playSurface model)
        , div
            [ Html.Attributes.class "discards-container" ]
            [ renderDiscardPile model.discards ( 100, 60, 10 ) ]
        ]


gameDetails : Model -> Html msg
gameDetails { draw_pile, fuses, clocks, my_data } =
    div [ Html.Attributes.class "game-details-container" ]
        [ div
            [ Html.Attributes.class "draw" ]
            [ Html.text ("Remaining Tiles: " ++ toString draw_pile) ]
        , div
            [ Html.Attributes.class "fuses" ]
            [ Html.text ("Fuses: " ++ toString fuses) ]
        , div
            [ Html.Attributes.class "timers" ]
            [ Html.text ("Clocks: " ++ toString clocks) ]
        , div
            [ Html.Attributes.class "turn" ]
            [ Html.text ("My Turn: " ++ toString my_data.turn) ]
        ]


playSurface : Model -> Html Msg
playSurface { fireworks, my_data, hands, clocks } =
    div [ Html.Attributes.class "game-surface-container" ]
        [ div
            [ Html.Attributes.class "fireworks-container" ]
            (renderFireworkPile fireworks ( 100, 60 ))
        , div [ Html.Attributes.class "hands-container" ]
            [ div
                [ Html.Attributes.class "player-container" ]
                [ div [ Html.Attributes.class "hand-label" ] [ Html.text ("My hand:") ]
                , renderPlayerHand
                    my_data.hand
                    ( 100, 60 )
                    my_data.turn
                ]
            , div
                [ Html.Attributes.class "team-container" ]
                (renderTeamHands hands ( 100, 60 ) (shouldShowButtons my_data.turn clocks))
            ]
        ]


shouldShowButtons : Bool -> Int -> Bool
shouldShowButtons myTurn clocks =
    myTurn && (clocks > 0)


renderFireworkPile : Fireworks -> ( Int, Int ) -> List (Html Msg)
renderFireworkPile fireworks dimensions =
    [ "blue", "green", "red", "white", "yellow" ]
        |> List.map (drawFireworkTile dimensions fireworks)


getNumber : String -> Fireworks -> Maybe Int
getNumber name fireworks =
    case name of
        "blue" ->
            fireworks.blue

        "green" ->
            fireworks.green

        "red" ->
            fireworks.red

        "white" ->
            fireworks.white

        "yellow" ->
            fireworks.yellow

        _ ->
            Nothing


drawFireworkTile : ( Int, Int ) -> Fireworks -> String -> Html Msg
drawFireworkTile dimensions fireworks color =
    let
        number =
            getNumber color fireworks
    in
        div [ Html.Attributes.class "tile" ]
            [ drawTileSvg dimensions ( Just color, number ) ]


renderDiscardPile : Hand -> ( Int, Int, Int ) -> Html Msg
renderDiscardPile hand ( width, height, padding ) =
    div []
        [ div [] [ Html.text "Discards:" ]
        , div [ Html.Attributes.class "discards" ]
            (List.map (drawTeamTile ( width, height )) hand)
        ]


renderTeamHands : Dict String Hand -> ( Int, Int ) -> Bool -> List (Html Msg)
renderTeamHands hands dimensions hintCtrls =
    hands
        |> Dict.map (renderTeamHand dimensions hintCtrls)
        |> Dict.values


renderTeamHand : ( Int, Int ) -> Bool -> String -> Hand -> Html Msg
renderTeamHand dimensions hintCtrls name hand =
    let
        hints =
            case hintCtrls of
                True ->
                    ((Html.text "Hint: ") :: hintButtons name hand)

                False ->
                    []
    in
        div []
            [ div [ Html.Attributes.class "hand-label" ] [ Html.text (name ++ "'s hand:") ]
            , div [ Html.Attributes.class "team-hand" ]
                (List.map (drawTeamTile dimensions) hand)
            , div [ Html.Attributes.class "hints-container" ] hints
            ]


hintButtons : String -> Hand -> List (Html Msg)
hintButtons name hand =
    hand
        |> List.concatMap tileAttributes
        |> Set.fromList
        |> Set.toList
        |> List.map (renderButton name)


renderButton : String -> String -> Html Msg
renderButton name hint =
    button [ onClick (Hint name hint) ] [ Html.text hint ]


tileAttributes : Tile -> List String
tileAttributes ( color, number ) =
    let
        c =
            Maybe.withDefault "" color

        n =
            toString (Maybe.withDefault 0 number)
    in
        [ c, n ]


renderPlayerHand : Hand -> ( Int, Int ) -> Bool -> Html Msg
renderPlayerHand hand dimensions my_turn =
    div [ Html.Attributes.class "player-hand" ]
        (List.indexedMap (drawPlayerTile dimensions my_turn) hand)


drawTileSvg : ( Int, Int ) -> Tile -> Svg Msg
drawTileSvg ( w, h ) tile =
    let
        baseStyle =
            "fill-opacity:0.4;stroke:black;stroke-width:3;stroke-opacity:0.6"

        style_ =
            case tile of
                ( Just color, Nothing ) ->
                    (baseStyle ++ ";fill:" ++ color)

                ( Nothing, Nothing ) ->
                    baseStyle

                ( Nothing, Just number ) ->
                    baseStyle

                _ ->
                    ""
    in
        Svg.svg
            [ Svg.Attributes.height (toString h)
            , Svg.Attributes.width (toString w)
            ]
            [ rect
                [ width (toString w)
                , height (toString h)
                , rx "10"
                , style style_
                ]
                []
            , renderFirework 0 0 tile
            ]


drawPlayerTile : ( Int, Int ) -> Bool -> Int -> Tile -> Html Msg
drawPlayerTile dimensions my_turn idx tile =
    div [ Html.Attributes.class "tile" ]
        [ (drawTileSvg dimensions tile)
        , div [ Html.Attributes.class "tile-controls" ]
            [ (drawDiscardButton my_turn idx)
            , (drawPlayButton my_turn idx)
            ]
        ]


drawTeamTile : ( Int, Int ) -> Tile -> Html Msg
drawTeamTile dimensions tile =
    div [ Html.Attributes.class "tile" ]
        [ (drawTileSvg dimensions tile) ]


drawDiscardButton : Bool -> Int -> Html Msg
drawDiscardButton my_turn idx =
    case my_turn of
        True ->
            button [ onClick (Discard idx) ] [ Html.text "Discard" ]

        False ->
            div [] []


drawPlayButton : Bool -> Int -> Html Msg
drawPlayButton my_turn idx =
    case my_turn of
        True ->
            button [ onClick (Play idx) ] [ Html.text "Play" ]

        False ->
            div [] []


renderFirework : Int -> Int -> Tile -> Svg a
renderFirework xpos ypos ( color, number ) =
    case Maybe.withDefault 0 number of
        1 ->
            renderOne xpos ypos color

        2 ->
            renderTwo xpos ypos color

        3 ->
            renderThree xpos ypos color

        4 ->
            renderFour xpos ypos color

        5 ->
            renderFive xpos ypos color

        _ ->
            g [] []


renderOne : Int -> Int -> Maybe String -> Svg a
renderOne xpos ypos color =
    g []
        [ renderCircle (xpos + 30) (ypos + 20) color
        ]


renderTwo : Int -> Int -> Maybe String -> Svg a
renderTwo xpos ypos color =
    g []
        [ renderCircle (xpos + 30) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 20) color
        ]


renderThree : Int -> Int -> Maybe String -> Svg a
renderThree xpos ypos color =
    g []
        [ renderCircle (xpos + 30) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 20) color
        , renderCircle (xpos + 70) (ypos + 20) color
        ]


renderFour : Int -> Int -> Maybe String -> Svg a
renderFour xpos ypos color =
    g []
        [ renderCircle (xpos + 30) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 20) color
        , renderCircle (xpos + 70) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 40) color
        ]


renderFive : Int -> Int -> Maybe String -> Svg a
renderFive xpos ypos color =
    g []
        [ renderCircle (xpos + 30) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 20) color
        , renderCircle (xpos + 70) (ypos + 20) color
        , renderCircle (xpos + 50) (ypos + 40) color
        , renderCircle (xpos + 30) (ypos + 40) color
        ]


renderCircle : Int -> Int -> Maybe String -> Svg a
renderCircle x y color =
    Svg.circle
        [ cx (toString x)
        , cy (toString y)
        , r "5"
        , style ("fill: " ++ (Maybe.withDefault "black" color))
        ]
        []
