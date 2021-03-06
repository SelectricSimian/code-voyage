import Html exposing (Html, div, span, em, a, text, input, br)
import Html.Events exposing (onClick, on, targetValue)
import Html.Attributes exposing (placeholder, style)
import StartApp.Simple as StartApp

import Interpreter exposing (..)
import SExprParser as S
import ExprParser as X
import Illuminator as Illum
import Utils

import Dict exposing (Dict)


globals = Dict.fromList
    [("min", { history = LitHistory, result = FunVal
        { globalName = Just "min"
        , args = ["a", "b"]
        , body = IfExpr
            (AppExpr (LitExpr (PrimAtom LessPrim)) [(NamedExpr "a"), (NamedExpr "b")])
            (NamedExpr "a")
            (NamedExpr "b") }})]


type alias Model =
    { source : String
    , parsed : Maybe (List S.SExpr)
    , expressed : Maybe (List Expr)
    , evaluated : Maybe (List TrackedVal)
    , result : Maybe (List Val)
    , annotated : Maybe (List Illum.TrackedVal)
    }

type Action = NewSource String | Illuminate (List Illum.TrackedVal)

update : Action -> Model -> Model
update action model =
  case action of

    NewSource newSource ->
      let
        parsed = S.parse newSource

        expressed =
          parsed
            |> Maybe.withDefault []
            |> List.map (\sexpr () -> X.toExpr sexpr)
            |> Utils.requireAll

        evaluated = Maybe.map (List.map (eval globals)) expressed

        result = Maybe.map (List.map .result) evaluated

        annotated = Maybe.map (List.map Illum.annotateTracked) evaluated
      in
        { source = newSource
        , parsed = parsed
        , expressed = expressed
        , evaluated = evaluated
        , result = result
        , annotated = annotated
        }

    Illuminate newAnnotated ->
        { model | annotated = Just newAnnotated }


output : String -> a -> Html
output label content =
  div [ outputStyle ]
    [ span [ outputLabelStyle ] [ text label ]
    , br [] []
    , text (toString content) 
    ]


view : Signal.Address Action -> Model -> Html
view address model =
  div [ ]
    [ input
        [ placeholder "Source code"
        , on "input"
            targetValue 
            (Signal.message (Signal.forwardTo address NewSource))
        , inputStyle
        ]
        []
      , model.annotated
        |> Maybe.map
            (Illum.viewList
                Illum.viewTracked
                (Signal.forwardTo address Illuminate))
        |> Maybe.map (div [ outputStyle ])
        |> Maybe.withDefault (text "Nothing")
    ]


main =
  StartApp.start
    { model =
        { source = ""
        , parsed = Nothing
        , expressed = Nothing 
        , evaluated = Nothing
        , result = Nothing
        , annotated = Nothing
        }
    , view = view
    , update = update
    }


inputStyle : Html.Attribute
inputStyle =
  style
    [ ("width", "700px")
    , ("height", "40px")
    , ("box-sizing", "border-box")
    , ("padding", "5px 10px")
    , ("margin-top", "20px")
    , ("margin-left", "40px")
    , ("font-size", "20px")
    , ("font-family", "Source Code Pro, Menlo, Monospace")
    ]

outputLabelStyle : Html.Attribute
outputLabelStyle =
    style
      [ ("font-weight", "bold")
      , ("font-family", "Helvetica Neue, sans-serif")
      ]


outputStyle : Html.Attribute
outputStyle =
    style
    [ ("width", "700px")
    , ("margin-top", "20px")
    , ("margin-left", "40px")
    , ("font-size", "17px")
    , ("font-family", "Source Code Pro, Menlo, Monospace")
    ]
