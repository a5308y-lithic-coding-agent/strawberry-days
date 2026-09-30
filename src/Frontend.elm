module Frontend exposing (..)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Cycle
import Date exposing (Date)
import Dict
import Html exposing (Html, button, div, h1, h2, h3, h4, input, label, p, span, text)
import Html.Attributes as Attr exposing (class, classList)
import Html.Events exposing (onClick, onInput, onSubmit, stopPropagationOn)
import Json.Decode as Decode
import Lamdera
import Process
import Style
import Task
import Time
import Types exposing (..)
import Url


type alias Model =
    FrontendModel


app =
    Lamdera.frontend
        { init = init
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , update = update
        , updateFromBackend = updateFromBackend
        , subscriptions = subscriptions
        , view = view
        }


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init _ key =
    ( { key = key
      , zone = Time.utc
      , today = Nothing
      , auth = Checking
      , passcode = ""
      , passcodeConfirm = ""
      , authError = Nothing
      , days = Dict.empty
      , settings = defaultSettings
      , page = TodayPage
      , monthOffset = 0
      , editor = Nothing
      , settingsForm = settingsFormFrom defaultSettings
      , notice = Nothing
      }
    , Cmd.batch
        [ Task.perform identity (Task.map2 GotTime Time.here Time.now)
        , Lamdera.sendToBackend Hello
        ]
    )


subscriptions : Model -> Sub FrontendMsg
subscriptions _ =
    -- Keeps "today" right when the app stays open past midnight.
    Time.every (60 * 1000) Tick


settingsFormFrom : Settings -> SettingsForm
settingsFormFrom settings =
    { name = settings.name
    , cycleLength = String.fromInt settings.cycleLength
    , periodLength = String.fromInt settings.periodLength
    , currentPasscode = ""
    , newPasscode = ""
    }



-- UPDATE


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                External url ->
                    ( model, Nav.load url )

        UrlChanged _ ->
            ( model, Cmd.none )

        GotTime zone now ->
            ( { model | zone = zone, today = Just (Date.fromPosix zone now) }, Cmd.none )

        Tick now ->
            ( { model | today = Just (Date.fromPosix model.zone now) }, Cmd.none )

        PasscodeInput value ->
            ( { model | passcode = value, authError = Nothing }, Cmd.none )

        PasscodeConfirmInput value ->
            ( { model | passcodeConfirm = value, authError = Nothing }, Cmd.none )

        SubmitSetup ->
            if String.length model.passcode < 4 then
                ( { model | authError = Just "Please use at least 4 characters." }, Cmd.none )

            else if model.passcode /= model.passcodeConfirm then
                ( { model | authError = Just "The passcodes don't match." }, Cmd.none )

            else
                ( model, Lamdera.sendToBackend (SetupPasscode model.passcode) )

        SubmitLogin ->
            if String.isEmpty model.passcode then
                ( model, Cmd.none )

            else
                ( model, Lamdera.sendToBackend (Login model.passcode) )

        GoTo page ->
            ( { model | page = page, monthOffset = 0 }, Cmd.none )

        ChangeMonth delta ->
            ( { model | monthOffset = model.monthOffset + delta }, Cmd.none )

        OpenDay day ->
            ( { model
                | editor =
                    Just
                        { day = day
                        , entry = Dict.get day model.days |> Maybe.withDefault emptyEntry
                        }
              }
            , Cmd.none
            )

        CloseEditor ->
            ( { model | editor = Nothing }, Cmd.none )

        SetFlow flow ->
            ( updateEntry (\entry -> { entry | flow = flow }) model, Cmd.none )

        ToggleMood mood ->
            ( updateEntry
                (\entry ->
                    { entry
                        | mood =
                            if entry.mood == Just mood then
                                Nothing

                            else
                                Just mood
                    }
                )
                model
            , Cmd.none
            )

        ToggleSymptom symptom ->
            ( updateEntry
                (\entry ->
                    { entry
                        | symptoms =
                            if List.member symptom entry.symptoms then
                                List.filter ((/=) symptom) entry.symptoms

                            else
                                entry.symptoms ++ [ symptom ]
                    }
                )
                model
            , Cmd.none
            )

        NoteInput note ->
            ( updateEntry (\entry -> { entry | note = note }) model, Cmd.none )

        SaveEditor ->
            case model.editor of
                Just editor ->
                    saveDay editor.day editor.entry { model | editor = Nothing }
                        |> withNotice "Saved 🍓"

                Nothing ->
                    ( model, Cmd.none )

        ClearEditorDay ->
            case model.editor of
                Just editor ->
                    saveDay editor.day emptyEntry { model | editor = Nothing }
                        |> withNotice "Day cleared"

                Nothing ->
                    ( model, Cmd.none )

        LogPeriodToday ->
            case model.today of
                Just today ->
                    let
                        day =
                            Date.toRataDie today

                        entry =
                            Dict.get day model.days |> Maybe.withDefault emptyEntry
                    in
                    saveDay day { entry | flow = Just Medium } model
                        |> withNotice "Logged. Be gentle with yourself today 🍓"

                Nothing ->
                    ( model, Cmd.none )

        SettingsNameInput value ->
            ( updateSettingsForm (\form -> { form | name = value }) model, Cmd.none )

        SettingsCycleInput value ->
            ( updateSettingsForm (\form -> { form | cycleLength = value }) model, Cmd.none )

        SettingsPeriodInput value ->
            ( updateSettingsForm (\form -> { form | periodLength = value }) model, Cmd.none )

        SubmitSettings ->
            case ( String.toInt model.settingsForm.cycleLength, String.toInt model.settingsForm.periodLength ) of
                ( Just cycleLength, Just periodLength ) ->
                    let
                        settings =
                            { name = String.trim model.settingsForm.name
                            , cycleLength = clamp 20 45 cycleLength
                            , periodLength = clamp 1 10 periodLength
                            }
                    in
                    ( { model | settings = settings, settingsForm = settingsFormFrom settings }
                    , Lamdera.sendToBackend (SaveSettings settings)
                    )
                        |> withNotice "Settings saved"

                _ ->
                    ( model, Cmd.none ) |> withNotice "Cycle and period length need to be numbers"

        CurrentPasscodeInput value ->
            ( updateSettingsForm (\form -> { form | currentPasscode = value }) model, Cmd.none )

        NewPasscodeInput value ->
            ( updateSettingsForm (\form -> { form | newPasscode = value }) model, Cmd.none )

        SubmitPasscodeChange ->
            if String.length model.settingsForm.newPasscode < 4 then
                ( model, Cmd.none ) |> withNotice "The new passcode needs at least 4 characters"

            else
                ( model
                , Lamdera.sendToBackend
                    (ChangePasscode model.settingsForm.currentPasscode model.settingsForm.newPasscode)
                )

        LogOut ->
            ( model, Lamdera.sendToBackend Logout )

        DismissNotice message ->
            if model.notice == Just message then
                ( { model | notice = Nothing }, Cmd.none )

            else
                ( model, Cmd.none )

        NoOpFrontendMsg ->
            ( model, Cmd.none )


updateEntry : (DayEntry -> DayEntry) -> Model -> Model
updateEntry f model =
    { model | editor = Maybe.map (\editor -> { editor | entry = f editor.entry }) model.editor }


updateSettingsForm : (SettingsForm -> SettingsForm) -> Model -> Model
updateSettingsForm f model =
    { model | settingsForm = f model.settingsForm }


saveDay : Int -> DayEntry -> Model -> ( Model, Cmd FrontendMsg )
saveDay day entry model =
    let
        cleaned =
            { entry | note = String.trim entry.note }
    in
    if cleaned == emptyEntry then
        ( { model | days = Dict.remove day model.days }, Lamdera.sendToBackend (DeleteDay day) )

    else
        ( { model | days = Dict.insert day cleaned model.days }, Lamdera.sendToBackend (SaveDay day cleaned) )


withNotice : String -> ( Model, Cmd FrontendMsg ) -> ( Model, Cmd FrontendMsg )
withNotice message ( model, cmd ) =
    ( { model | notice = Just message }
    , Cmd.batch [ cmd, Process.sleep 2500 |> Task.perform (\_ -> DismissNotice message) ]
    )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        AskForSetup ->
            ( { model | auth = FirstRun }, Cmd.none )

        AskForPasscode ->
            ( { model | auth = Locked }, Cmd.none )

        Unlock data ->
            ( { model
                | auth = Unlocked
                , days = data.days
                , settings = data.settings
                , settingsForm = settingsFormFrom data.settings
                , passcode = ""
                , passcodeConfirm = ""
                , authError = Nothing
              }
            , Cmd.none
            )

        AuthError error ->
            ( { model | authError = Just error, passcode = "" }, Cmd.none )

        DayChanged day maybeEntry ->
            ( { model
                | days =
                    case maybeEntry of
                        Just entry ->
                            Dict.insert day entry model.days

                        Nothing ->
                            Dict.remove day model.days
              }
            , Cmd.none
            )

        SettingsChanged settings ->
            ( { model | settings = settings, settingsForm = settingsFormFrom settings }, Cmd.none )

        PasscodeChangeResult (Ok ()) ->
            ( updateSettingsForm (\form -> { form | currentPasscode = "", newPasscode = "" }) model, Cmd.none )
                |> withNotice "Passcode changed. Other devices were signed out."

        PasscodeChangeResult (Err error) ->
            ( model, Cmd.none ) |> withNotice error

        Lock ->
            ( { model
                | auth = Locked
                , days = Dict.empty
                , settings = defaultSettings
                , settingsForm = settingsFormFrom defaultSettings
                , editor = Nothing
                , page = TodayPage
                , passcode = ""
              }
            , Cmd.none
            )



-- VIEW


view : Model -> Browser.Document FrontendMsg
view model =
    { title = "Strawberry Days"
    , body =
        [ Html.node "style" [] [ text Style.css ]
        , case ( model.auth, model.today ) of
            ( Unlocked, Just today ) ->
                viewApp model today

            ( FirstRun, _ ) ->
                viewSetup model

            ( Locked, _ ) ->
                viewLogin model

            _ ->
                div [ class "splash" ] [ text "🍓" ]
        ]
    }


viewApp : Model -> Date -> Html FrontendMsg
viewApp model today =
    let
        summary =
            Cycle.summarize model.settings (Date.toRataDie today) model.days
    in
    div []
        [ div [ class "app" ]
            [ case model.page of
                TodayPage ->
                    viewToday model today summary

                CalendarPage ->
                    viewCalendar model today summary

                InsightsPage ->
                    viewInsights model summary

                SettingsPage ->
                    viewSettings model
            ]
        , viewNav model.page
        , case model.editor of
            Just editor ->
                viewEditor editor

            Nothing ->
                text ""
        , case model.notice of
            Just notice ->
                div [ class "notice", Attr.attribute "role" "status" ] [ text notice ]

            Nothing ->
                text ""
        ]


viewHeader : String -> String -> Html msg
viewHeader title sub =
    div [ class "header" ]
        [ h1 [] [ text title ]
        , if String.isEmpty sub then
            text ""

          else
            div [ class "sub" ] [ text sub ]
        ]


viewNav : Page -> Html FrontendMsg
viewNav current =
    let
        item page icon name =
            button
                [ classList [ ( "active", page == current ) ]
                , onClick (GoTo page)
                ]
                [ span [ class "icon" ] [ text icon ], text name ]
    in
    Html.nav [ class "nav" ]
        [ div [ class "nav-inner" ]
            [ item TodayPage "🍓" "Today"
            , item CalendarPage "📅" "Calendar"
            , item InsightsPage "🌱" "Insights"
            , item SettingsPage "⚙️" "Settings"
            ]
        ]



-- TODAY


viewToday : Model -> Date -> Cycle.Summary -> Html FrontendMsg
viewToday model today summary =
    let
        todayEntry =
            Dict.get summary.today model.days

        bleedingToday =
            Maybe.map Cycle.isBleeding todayEntry |> Maybe.withDefault False

        inPeriod =
            summary.current |> Maybe.map .inPeriod |> Maybe.withDefault False

        greeting =
            if String.isEmpty model.settings.name then
                "Hi there"

            else
                "Hi " ++ model.settings.name
    in
    div []
        [ viewHeader greeting (Date.format "EEEE, MMMM d" today)
        , viewRing summary
        , div [ class "actions" ]
            [ if bleedingToday then
                text ""

              else
                button [ class "btn primary", onClick LogPeriodToday ]
                    [ text
                        (if inPeriod then
                            "🍓 Log period today"

                         else
                            "🍓 Period started today"
                        )
                    ]
            , button [ class "btn secondary", onClick (OpenDay summary.today) ]
                [ text
                    (if todayEntry == Nothing then
                        "Log how you feel today"

                     else
                        "Edit today"
                    )
                ]
            ]
        , viewPhase summary
        , viewUpcoming summary
        , p [ class "fineprint" ] [ text disclaimer ]
        ]


disclaimer : String
disclaimer =
    "Predictions are estimates based on your logged cycles. They are not medical advice and not reliable for contraception."


viewRing : Cycle.Summary -> Html msg
viewRing summary =
    let
        ( big, small, progress ) =
            case summary.current of
                Nothing ->
                    ( "🍓", "Log your last period to see predictions", 0 )

                Just c ->
                    let
                        cycleProgress =
                            min 1 (toFloat c.cycleDay / toFloat summary.avgCycle)
                    in
                    if c.inPeriod then
                        ( "Day " ++ String.fromInt c.cycleDay, "of your period", cycleProgress )

                    else if c.daysUntil < 0 then
                        ( days (negate c.daysUntil), "late", 1 )

                    else if c.daysUntil == 0 then
                        ( "Today", "period expected", 1 )

                    else
                        ( days c.daysUntil, "until your period", cycleProgress )

        degrees =
            String.fromFloat (progress * 360)
    in
    div
        [ class "ring"
        , Attr.style "background" ("conic-gradient(var(--berry) " ++ degrees ++ "deg, var(--track) 0deg)")
        ]
        [ div [ class "ring-inner" ]
            [ div [ class "ring-big" ] [ text big ]
            , div [ class "ring-small" ] [ text small ]
            , case summary.current of
                Just c ->
                    div [ class "ring-caption" ] [ text ("Cycle day " ++ String.fromInt c.cycleDay) ]

                Nothing ->
                    text ""
            ]
        ]


viewPhase : Cycle.Summary -> Html msg
viewPhase summary =
    let
        ( title, body ) =
            case Cycle.phase summary of
                Nothing ->
                    ( "Getting started"
                    , "Tap “Period started today” when your next period begins, or open the calendar and tap the days of your most recent period. Predictions get better with every cycle you log."
                    )

                Just Cycle.Menstrual ->
                    ( "🩸 Period"
                    , "Rest, warmth and your favourite snacks are all encouraged. A hot water bottle can help with cramps."
                    )

                Just Cycle.Follicular ->
                    ( "🌱 Follicular phase"
                    , "Energy often picks up after a period. A nice time for new plans and workouts."
                    )

                Just Cycle.Fertile ->
                    ( "🌸 Fertile window"
                    , "You're in your estimated fertile window."
                    )

                Just Cycle.Ovulation ->
                    ( "🌸 Estimated ovulation"
                    , "Today is your estimated ovulation day, the peak of the fertile window."
                    )

                Just Cycle.Luteal ->
                    ( "🌙 Luteal phase"
                    , "Some people notice PMS in the days before a period, like mood swings, bloating or cravings. Be kind to yourself."
                    )

                Just Cycle.Late ->
                    ( "⏳ Running late"
                    , "Your period is later than predicted. Cycles naturally vary, and stress, travel, illness or sleep can all shift things."
                    )
    in
    div [ class "card" ] [ h3 [] [ text title ], p [] [ text body ] ]


viewUpcoming : Cycle.Summary -> Html msg
viewUpcoming summary =
    case ( List.head summary.predictedStarts, Cycle.nextFertileWindow summary ) of
        ( Just start, window ) ->
            div [ class "card" ]
                [ h3 [] [ text "Coming up" ]
                , div [ class "rows" ]
                    [ viewRow "Next period" (formatDay start ++ relative summary.today start)
                    , case window of
                        Just w ->
                            viewRow "Fertile window" (formatDay w.start ++ " – " ++ formatDay w.end)

                        Nothing ->
                            text ""
                    , viewRow "Average cycle" (days summary.avgCycle)
                    ]
                ]

        ( Nothing, _ ) ->
            text ""


viewRow : String -> String -> Html msg
viewRow labelText value =
    div [ class "row" ] [ span [ class "label" ] [ text labelText ], span [ class "value" ] [ text value ] ]


relative : Int -> Int -> String
relative today day =
    if day == today then
        " (today)"

    else if day == today + 1 then
        " (tomorrow)"

    else
        ""



-- CALENDAR


viewCalendar : Model -> Date -> Cycle.Summary -> Html FrontendMsg
viewCalendar model today summary =
    let
        firstOfMonth =
            Date.add Date.Months model.monthOffset (Date.floor Date.Month today)

        lastOfMonth =
            Date.add Date.Days -1 (Date.add Date.Months 1 firstOfMonth)

        gridDays =
            Date.range Date.Day
                1
                (Date.floor Date.Monday firstOfMonth)
                (Date.add Date.Days 1 (Date.ceiling Date.Sunday lastOfMonth))
    in
    div []
        [ viewHeader "Calendar" ""
        , div [ class "month-nav" ]
            [ button [ class "icon-btn", onClick (ChangeMonth -1), Attr.attribute "aria-label" "Previous month" ] [ text "‹" ]
            , h2 [] [ text (Date.format "MMMM y" firstOfMonth) ]
            , button [ class "icon-btn", onClick (ChangeMonth 1), Attr.attribute "aria-label" "Next month" ] [ text "›" ]
            ]
        , div [ class "weekdays" ] (List.map (\d -> div [] [ text d ]) [ "M", "T", "W", "T", "F", "S", "S" ])
        , div [ class "grid" ] (List.map (viewDayCell model summary firstOfMonth) gridDays)
        , div [ class "legend" ]
            [ span [] [ span [ class "swatch flow" ] [], text "Period" ]
            , span [] [ span [ class "swatch predicted" ] [], text "Predicted period" ]
            , span [] [ span [ class "swatch fertile" ] [], text "Fertile" ]
            , span [] [ span [ class "swatch ovulation" ] [], text "Ovulation" ]
            ]
        , if model.monthOffset /= 0 then
            div [ class "actions" ] [ button [ class "btn ghost", onClick (GoTo CalendarPage) ] [ text "Back to this month" ] ]

          else
            text ""
        , p [ class "hint" ] [ text "Tap a day to log flow, mood and symptoms." ]
        ]


viewDayCell : Model -> Cycle.Summary -> Date -> Date -> Html FrontendMsg
viewDayCell model summary firstOfMonth date =
    let
        day =
            Date.toRataDie date

        entry =
            Dict.get day model.days

        flow =
            Maybe.andThen .flow entry

        info =
            Cycle.dayInfo summary day

        hasDetails =
            case entry of
                Just e ->
                    e.mood /= Nothing || not (List.isEmpty e.symptoms) || e.note /= ""

                Nothing ->
                    False

        isFuture =
            day > summary.today
    in
    button
        [ class "day"
        , classList
            [ ( "other-month", Date.month date /= Date.month firstOfMonth )
            , ( "today", day == summary.today )
            , ( "future", isFuture )
            , ( "fertile", info.fertile && flow == Nothing )
            , ( "ovulation", info.ovulation && flow == Nothing )
            , ( "predicted", info.predictedPeriod && flow == Nothing )
            , ( flowClass flow, flow /= Nothing )
            ]
        , Attr.disabled isFuture
        , Attr.attribute "aria-label" (Date.format "EEEE, MMMM d" date ++ Maybe.withDefault "" (Maybe.map (\f -> ", " ++ flowLabel f) flow))
        , onClick (OpenDay day)
        ]
        [ text (String.fromInt (Date.day date))
        , if hasDetails then
            span [ class "dot" ] []

          else
            text ""
        ]


flowClass : Maybe Flow -> String
flowClass flow =
    case flow of
        Just Spotting ->
            "flow-spotting"

        Just Light ->
            "flow-light"

        Just Medium ->
            "flow-medium"

        Just Heavy ->
            "flow-heavy"

        Nothing ->
            ""



-- DAY EDITOR


viewEditor : Editor -> Html FrontendMsg
viewEditor editor =
    let
        entry =
            editor.entry

        chip isOn extraClass msg content =
            button
                [ class ("chip " ++ extraClass)
                , classList [ ( "on", isOn ) ]
                , Attr.attribute "aria-pressed" (boolString isOn)
                , onClick msg
                ]
                [ text content ]
    in
    div [ class "backdrop", onClick CloseEditor ]
        [ div
            [ class "sheet"
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-modal" "true"
            , stopPropagationOn "click" (Decode.succeed ( NoOpFrontendMsg, True ))
            ]
            [ h2 [] [ text (Date.format "EEEE, MMMM d" (Date.fromRataDie editor.day)) ]
            , h4 [] [ text "Flow" ]
            , div [ class "chips" ]
                (chip (entry.flow == Nothing) "" (SetFlow Nothing) "None"
                    :: List.map
                        (\f -> chip (entry.flow == Just f) "" (SetFlow (Just f)) (flowIcon f ++ " " ++ flowLabel f))
                        [ Spotting, Light, Medium, Heavy ]
                )
            , h4 [] [ text "Mood" ]
            , div [ class "chips" ]
                (List.map
                    (\m -> chip (entry.mood == Just m) "leaf" (ToggleMood m) (moodLabel m))
                    [ Happy, Calm, Sensitive, Irritable, Sad, Anxious ]
                )
            , h4 [] [ text "Symptoms" ]
            , div [ class "chips" ]
                (List.map
                    (\s -> chip (List.member s entry.symptoms) "" (ToggleSymptom s) (symptomLabel s))
                    allSymptoms
                )
            , h4 [] [ text "Note" ]
            , Html.textarea
                [ Attr.value entry.note
                , onInput NoteInput
                , Attr.placeholder "Anything you want to remember…"
                ]
                []
            , div [ class "actions" ]
                [ button [ class "btn primary", onClick SaveEditor ] [ text "Save" ]
                , button [ class "btn ghost", onClick CloseEditor ] [ text "Cancel" ]
                , if entry /= emptyEntry then
                    button [ class "btn danger", onClick ClearEditorDay ] [ text "Clear this day" ]

                  else
                    text ""
                ]
            ]
        ]


allSymptoms : List Symptom
allSymptoms =
    [ Cramps, Headache, Bloating, Fatigue, TenderBreasts, Acne, Cravings, BackPain, Nausea ]


flowLabel : Flow -> String
flowLabel flow =
    case flow of
        Spotting ->
            "Spotting"

        Light ->
            "Light"

        Medium ->
            "Medium"

        Heavy ->
            "Heavy"


flowIcon : Flow -> String
flowIcon flow =
    case flow of
        Spotting ->
            "·"

        Light ->
            "🍓"

        Medium ->
            "🍓🍓"

        Heavy ->
            "🍓🍓🍓"


moodLabel : Mood -> String
moodLabel mood =
    case mood of
        Happy ->
            "😊 Happy"

        Calm ->
            "😌 Calm"

        Sensitive ->
            "🥺 Sensitive"

        Irritable ->
            "😤 Irritable"

        Sad ->
            "😢 Sad"

        Anxious ->
            "😰 Anxious"


symptomLabel : Symptom -> String
symptomLabel symptom =
    case symptom of
        Cramps ->
            "Cramps"

        Headache ->
            "Headache"

        Bloating ->
            "Bloating"

        Fatigue ->
            "Tired"

        TenderBreasts ->
            "Tender breasts"

        Acne ->
            "Acne"

        Cravings ->
            "Cravings"

        BackPain ->
            "Back pain"

        Nausea ->
            "Nausea"



-- INSIGHTS


viewInsights : Model -> Cycle.Summary -> Html FrontendMsg
viewInsights model summary =
    let
        hasHistory =
            summary.cyclesTracked > 0

        tile labelText value unit =
            div [ class "tile" ]
                [ div [ class "tile-label" ] [ text labelText ]
                , div [ class "tile-value" ] [ text value, span [ class "tile-unit" ] [ text unit ] ]
                ]

        symptomCounts =
            allSymptoms
                |> List.map
                    (\s ->
                        ( s
                        , Dict.values model.days
                            |> List.filter (\e -> List.member s e.symptoms)
                            |> List.length
                        )
                    )
                |> List.filter (\( _, n ) -> n > 0)
                |> List.sortBy (\( _, n ) -> negate n)
                |> List.take 5
    in
    div []
        [ viewHeader "Insights" ""
        , div [ class "tiles" ]
            [ tile "Avg. cycle" (String.fromInt summary.avgCycle) " d"
            , tile "Avg. period" (String.fromInt summary.avgPeriod) " d"
            , tile "Cycles logged" (String.fromInt summary.cyclesTracked) ""
            ]
        , if hasHistory then
            text ""

          else
            p [ class "hint" ] [ text "Averages use your settings until you've logged a full cycle." ]
        , viewCycleHistory summary
        , if List.isEmpty symptomCounts then
            text ""

          else
            div [ class "card" ]
                [ h3 [] [ text "Most logged symptoms" ]
                , div [ class "rows" ]
                    (List.map
                        (\( s, n ) -> viewRow (symptomLabel s) (days n))
                        symptomCounts
                    )
                ]
        ]


viewCycleHistory : Cycle.Summary -> Html msg
viewCycleHistory summary =
    let
        completed =
            Cycle.cycleLengths summary.periods
                |> List.map (\( period, length ) -> ( period, String.fromInt length ))

        ongoing =
            case List.reverse summary.periods of
                last :: _ ->
                    [ ( last, "ongoing" ) ]

                [] ->
                    []

        rows =
            List.reverse (completed ++ ongoing) |> List.take 12
    in
    if List.isEmpty rows then
        text ""

    else
        div [ class "card" ]
            [ h3 [] [ text "Recent cycles" ]
            , Html.table []
                [ Html.thead []
                    [ Html.tr []
                        [ Html.th [] [ text "Started" ]
                        , Html.th [ class "num" ] [ text "Period (days)" ]
                        , Html.th [ class "num" ] [ text "Cycle (days)" ]
                        ]
                    ]
                , Html.tbody []
                    (List.map
                        (\( period, cycle ) ->
                            Html.tr []
                                [ Html.td [] [ text (formatDay period.start) ]
                                , Html.td [ class "num" ] [ text (String.fromInt (period.end - period.start + 1)) ]
                                , Html.td [ class "num" ] [ text cycle ]
                                ]
                        )
                        rows
                    )
                ]
            ]



-- SETTINGS


viewSettings : Model -> Html FrontendMsg
viewSettings model =
    let
        form =
            model.settingsForm
    in
    div []
        [ viewHeader "Settings" ""
        , Html.form [ class "card", onSubmit SubmitSettings ]
            [ h3 [] [ text "About you" ]
            , field "Your name" [ Attr.type_ "text", Attr.value form.name, onInput SettingsNameInput, Attr.placeholder "Optional" ]
            , field "Typical cycle length (days)"
                [ Attr.type_ "number", Attr.min "20", Attr.max "45", Attr.value form.cycleLength, onInput SettingsCycleInput ]
            , field "Typical period length (days)"
                [ Attr.type_ "number", Attr.min "1", Attr.max "10", Attr.value form.periodLength, onInput SettingsPeriodInput ]
            , p [] [ text "Used for predictions until you've logged a few cycles. After that, your own history takes over." ]
            , div [ class "actions" ] [ button [ class "btn primary", Attr.type_ "submit" ] [ text "Save" ] ]
            ]
        , Html.form [ class "card", onSubmit SubmitPasscodeChange ]
            [ h3 [] [ text "Passcode" ]
            , field "Current passcode"
                [ Attr.type_ "password", Attr.value form.currentPasscode, onInput CurrentPasscodeInput, Attr.attribute "autocomplete" "current-password" ]
            , field "New passcode"
                [ Attr.type_ "password", Attr.value form.newPasscode, onInput NewPasscodeInput, Attr.attribute "autocomplete" "new-password" ]
            , div [ class "actions" ] [ button [ class "btn secondary", Attr.type_ "submit" ] [ text "Change passcode" ] ]
            ]
        , div [ class "actions" ] [ button [ class "btn danger", onClick LogOut ] [ text "Lock on this device" ] ]
        , p [ class "fineprint" ]
            [ text "Strawberry Days predicts your next period from the average of your last few cycles, and your fertile window from an estimated ovulation 14 days before it. "
            , text disclaimer
            ]
        ]


field : String -> List (Html.Attribute msg) -> Html msg
field labelText attributes =
    label [ class "field" ] [ span [] [ text labelText ], input attributes [] ]



-- AUTH


viewSetup : Model -> Html FrontendMsg
viewSetup model =
    div [ class "auth" ]
        [ div [ class "berry" ] [ text "🍓" ]
        , h1 [] [ text "Strawberry Days" ]
        , p [] [ text "A cosy, private place to track your cycle. Choose a passcode to keep it just for you." ]
        , Html.form [ onSubmit SubmitSetup ]
            [ field "Passcode"
                [ Attr.type_ "password", Attr.value model.passcode, onInput PasscodeInput, Attr.attribute "autocomplete" "new-password", Attr.autofocus True ]
            , field "Repeat passcode"
                [ Attr.type_ "password", Attr.value model.passcodeConfirm, onInput PasscodeConfirmInput, Attr.attribute "autocomplete" "new-password" ]
            , viewAuthError model.authError
            , button [ class "btn primary", Attr.type_ "submit" ] [ text "Start tracking" ]
            ]
        ]


viewLogin : Model -> Html FrontendMsg
viewLogin model =
    div [ class "auth" ]
        [ div [ class "berry" ] [ text "🍓" ]
        , h1 [] [ text "Welcome back" ]
        , p [] [ text "Enter your passcode to open Strawberry Days." ]
        , Html.form [ onSubmit SubmitLogin ]
            [ field "Passcode"
                [ Attr.type_ "password", Attr.value model.passcode, onInput PasscodeInput, Attr.attribute "autocomplete" "current-password", Attr.autofocus True ]
            , viewAuthError model.authError
            , button [ class "btn primary", Attr.type_ "submit" ] [ text "Unlock" ]
            ]
        ]


viewAuthError : Maybe String -> Html msg
viewAuthError error =
    case error of
        Just message ->
            p [ class "error", Attr.attribute "role" "alert" ] [ text message ]

        Nothing ->
            text ""



-- FORMATTING


formatDay : Int -> String
formatDay day =
    Date.format "EEE, MMM d" (Date.fromRataDie day)


days : Int -> String
days n =
    String.fromInt n
        ++ (if n == 1 then
                " day"

            else
                " days"
           )


boolString : Bool -> String
boolString b =
    if b then
        "true"

    else
        "false"
