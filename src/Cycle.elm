module Cycle exposing
    ( Current
    , DayInfo
    , Period
    , Phase(..)
    , Summary
    , Window
    , cycleLengths
    , dayInfo
    , isBleeding
    , nextFertileWindow
    , periods
    , phase
    , summarize
    )

{-| Cycle detection and predictions. All days are Rata Die numbers.

Predictions follow the usual calendar method: the next period is expected one
average cycle after the last one started, and ovulation roughly 14 days before
the next period. These are estimates, not medical advice or contraception.

-}

import Dict exposing (Dict)
import Types exposing (..)


type alias Period =
    { start : Int
    , end : Int
    }


type alias Window =
    { start : Int
    , end : Int
    , ovulation : Int
    }


type alias Current =
    { start : Int
    , cycleDay : Int
    , nextStart : Int
    , daysUntil : Int
    , inPeriod : Bool
    }


type alias Summary =
    { today : Int
    , avgCycle : Int
    , avgPeriod : Int
    , cyclesTracked : Int
    , periods : List Period
    , current : Maybe Current
    , predictedStarts : List Int
    , fertileWindows : List Window
    }


type Phase
    = Menstrual
    | Follicular
    | Fertile
    | Ovulation
    | Luteal
    | Late


type alias DayInfo =
    { predictedPeriod : Bool
    , fertile : Bool
    , ovulation : Bool
    }


{-| Bleeding days within this many days of each other belong to the same period.
-}
maxGapWithinPeriod : Int
maxGapWithinPeriod =
    3


{-| Cycles outside this range are most likely missed logs, so they don't count
towards the averages.
-}
plausibleCycle : Int -> Bool
plausibleCycle length =
    length >= 15 && length <= 60


historySize : Int
historySize =
    6


predictionCount : Int
predictionCount =
    6


isBleeding : DayEntry -> Bool
isBleeding entry =
    case entry.flow of
        Just Spotting ->
            False

        Just _ ->
            True

        Nothing ->
            False


periods : Dict Int DayEntry -> List Period
periods days =
    days
        |> Dict.filter (\_ entry -> isBleeding entry)
        |> Dict.keys
        |> List.foldl
            (\day acc ->
                case acc of
                    period :: rest ->
                        if day - period.end <= maxGapWithinPeriod then
                            { period | end = day } :: rest

                        else
                            { start = day, end = day } :: acc

                    [] ->
                        [ { start = day, end = day } ]
            )
            []
        |> List.reverse


{-| Length of each completed cycle, paired with the period that started it.
-}
cycleLengths : List Period -> List ( Period, Int )
cycleLengths ps =
    List.map2 (\a b -> ( a, b.start - a.start )) ps (List.drop 1 ps)


summarize : Settings -> Int -> Dict Int DayEntry -> Summary
summarize settings today days =
    let
        ps =
            periods days |> List.filter (\p -> p.start <= today)

        recentCycles =
            cycleLengths ps
                |> List.map Tuple.second
                |> List.filter plausibleCycle
                |> takeLast historySize

        avgCycle =
            averageOr settings.cycleLength recentCycles

        lastPeriod =
            List.head (List.reverse ps)

        -- A period that ended yesterday or later may still be going on.
        completedPeriods =
            case lastPeriod of
                Just last ->
                    if last.end >= today - 1 then
                        List.take (List.length ps - 1) ps

                    else
                        ps

                Nothing ->
                    []

        avgPeriod =
            completedPeriods
                |> List.map (\p -> p.end - p.start + 1)
                |> takeLast historySize
                |> averageOr settings.periodLength
                |> clamp 1 14

        current =
            Maybe.map
                (\last ->
                    let
                        nextStart =
                            last.start + avgCycle
                    in
                    { start = last.start
                    , cycleDay = today - last.start + 1
                    , nextStart = nextStart
                    , daysUntil = nextStart - today
                    , inPeriod =
                        (last.end == today)
                            || (last.end == today - 1 && today - last.start < avgPeriod)
                    }
                )
                lastPeriod

        predictedStarts =
            case current of
                Just c ->
                    -- When late, the period is expected any day now.
                    List.range 0 (predictionCount - 1)
                        |> List.map (\i -> max c.nextStart today + i * avgCycle)

                Nothing ->
                    []

        fertileWindows =
            case current of
                Just c ->
                    (c.start :: predictedStarts)
                        |> List.map (\start -> fertileWindow (start + avgCycle))

                Nothing ->
                    []
    in
    { today = today
    , avgCycle = avgCycle
    , avgPeriod = avgPeriod
    , cyclesTracked = List.length recentCycles
    , periods = ps
    , current = current
    , predictedStarts = predictedStarts
    , fertileWindows = fertileWindows
    }


fertileWindow : Int -> Window
fertileWindow nextPeriodStart =
    let
        ovulation =
            nextPeriodStart - 14
    in
    { start = ovulation - 5, end = ovulation + 1, ovulation = ovulation }


phase : Summary -> Maybe Phase
phase summary =
    Maybe.map
        (\c ->
            let
                window =
                    fertileWindow c.nextStart
            in
            if c.inPeriod then
                Menstrual

            else if c.daysUntil < 0 then
                Late

            else if summary.today == window.ovulation then
                Ovulation

            else if summary.today >= window.start && summary.today <= window.end then
                Fertile

            else if summary.today < window.start then
                Follicular

            else
                Luteal
        )
        summary.current


nextFertileWindow : Summary -> Maybe Window
nextFertileWindow summary =
    summary.fertileWindows
        |> List.filter (\w -> w.end >= summary.today)
        |> List.head


dayInfo : Summary -> Int -> DayInfo
dayInfo summary day =
    let
        inWindow w =
            day >= w.start && day <= w.end && day > currentStart

        currentStart =
            summary.current |> Maybe.map .start |> Maybe.withDefault day
    in
    { predictedPeriod =
        day
            >= summary.today
            && List.any (\start -> day >= start && day < start + summary.avgPeriod) summary.predictedStarts
    , fertile = List.any inWindow summary.fertileWindows
    , ovulation = List.any (\w -> inWindow w && w.ovulation == day) summary.fertileWindows
    }



-- HELPERS


averageOr : Int -> List Int -> Int
averageOr fallback values =
    if List.isEmpty values then
        fallback

    else
        round (toFloat (List.sum values) / toFloat (List.length values))


takeLast : Int -> List a -> List a
takeLast n list =
    List.drop (List.length list - n) list
