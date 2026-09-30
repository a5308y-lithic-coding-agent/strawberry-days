module Backend exposing (..)

import Dict
import Lamdera exposing (ClientId, SessionId)
import Set
import Sha256
import Task
import Time
import Types exposing (..)


type alias Model =
    BackendModel


app =
    Lamdera.backend
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = \_ -> Sub.none
        }


init : ( Model, Cmd BackendMsg )
init =
    ( { credentials = Nothing
      , sessions = Set.empty
      , days = Dict.empty
      , settings = defaultSettings
      , failedLogins = 0
      , lockedUntil = 0
      }
    , Cmd.none
    )


maxFailedLogins : Int
maxFailedLogins =
    5


lockoutMillis : Int
lockoutMillis =
    5 * 60 * 1000


update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
update msg model =
    case msg of
        SetupAt sessionId clientId passcode now ->
            case model.credentials of
                Nothing ->
                    let
                        newModel =
                            { model
                                | credentials = Just (makeCredentials sessionId passcode now)
                                , sessions = Set.singleton sessionId
                            }
                    in
                    ( newModel, Lamdera.sendToFrontend sessionId (Unlock (appData newModel)) )

                Just _ ->
                    -- Someone already claimed the app in the meantime.
                    ( model, Lamdera.sendToFrontend clientId AskForPasscode )

        LoginAt sessionId clientId passcode now ->
            let
                millis =
                    Time.posixToMillis now
            in
            if millis < model.lockedUntil then
                ( model
                , Lamdera.sendToFrontend clientId (AuthError (lockedMessage (model.lockedUntil - millis)))
                )

            else if passcodeMatches model passcode then
                let
                    newModel =
                        { model | sessions = Set.insert sessionId model.sessions, failedLogins = 0 }
                in
                ( newModel, Lamdera.sendToFrontend sessionId (Unlock (appData newModel)) )

            else if model.failedLogins + 1 >= maxFailedLogins then
                ( { model | failedLogins = 0, lockedUntil = millis + lockoutMillis }
                , Lamdera.sendToFrontend clientId (AuthError (lockedMessage lockoutMillis))
                )

            else
                ( { model | failedLogins = model.failedLogins + 1 }
                , Lamdera.sendToFrontend clientId (AuthError "That passcode isn't right.")
                )

        ChangePasscodeAt sessionId clientId current new now ->
            if not (passcodeMatches model current) then
                ( model, Lamdera.sendToFrontend clientId (PasscodeChangeResult (Err "Your current passcode isn't right.")) )

            else
                -- Changing the passcode signs out every other device.
                ( { model
                    | credentials = Just (makeCredentials sessionId new now)
                    , sessions = Set.singleton sessionId
                  }
                , Cmd.batch
                    (Lamdera.sendToFrontend clientId (PasscodeChangeResult (Ok ()))
                        :: (Set.remove sessionId model.sessions
                                |> Set.toList
                                |> List.map (\other -> Lamdera.sendToFrontend other Lock)
                           )
                    )
                )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
updateFromFrontend sessionId clientId msg model =
    let
        authorized =
            Set.member sessionId model.sessions
    in
    case msg of
        Hello ->
            ( model
            , Lamdera.sendToFrontend clientId
                (if model.credentials == Nothing then
                    AskForSetup

                 else if authorized then
                    Unlock (appData model)

                 else
                    AskForPasscode
                )
            )

        SetupPasscode passcode ->
            if model.credentials == Nothing && String.length passcode >= 4 then
                ( model, Task.perform (SetupAt sessionId clientId passcode) Time.now )

            else
                ( model, Cmd.none )

        Login passcode ->
            ( model, Task.perform (LoginAt sessionId clientId passcode) Time.now )

        Logout ->
            ( { model | sessions = Set.remove sessionId model.sessions }
            , Lamdera.sendToFrontend sessionId Lock
            )

        SaveDay day entry ->
            if authorized then
                ( { model | days = Dict.insert day entry model.days }
                , toSignedIn model (DayChanged day (Just entry))
                )

            else
                ( model, Cmd.none )

        DeleteDay day ->
            if authorized then
                ( { model | days = Dict.remove day model.days }
                , toSignedIn model (DayChanged day Nothing)
                )

            else
                ( model, Cmd.none )

        SaveSettings settings ->
            if authorized then
                ( { model | settings = settings }
                , toSignedIn model (SettingsChanged settings)
                )

            else
                ( model, Cmd.none )

        ChangePasscode current new ->
            if authorized && String.length new >= 4 then
                ( model, Task.perform (ChangePasscodeAt sessionId clientId current new) Time.now )

            else
                ( model, Cmd.none )



-- HELPERS


appData : Model -> AppData
appData model =
    { days = model.days, settings = model.settings }


{-| Send a message to every device that is currently signed in.
-}
toSignedIn : Model -> ToFrontend -> Cmd BackendMsg
toSignedIn model msg =
    model.sessions
        |> Set.toList
        |> List.map (\sessionId -> Lamdera.sendToFrontend sessionId msg)
        |> Cmd.batch


makeCredentials : SessionId -> String -> Time.Posix -> Credentials
makeCredentials sessionId passcode now =
    let
        salt =
            Sha256.sha256 (sessionId ++ String.fromInt (Time.posixToMillis now))
    in
    { salt = salt, hash = hashPasscode salt passcode }


hashPasscode : String -> String -> String
hashPasscode salt passcode =
    Sha256.sha256 (salt ++ ":" ++ passcode)


passcodeMatches : Model -> String -> Bool
passcodeMatches model passcode =
    case model.credentials of
        Just credentials ->
            hashPasscode credentials.salt passcode == credentials.hash

        Nothing ->
            False


lockedMessage : Int -> String
lockedMessage remainingMillis =
    let
        minutes =
            max 1 (ceiling (toFloat remainingMillis / 60000))
    in
    "Too many tries. Please wait "
        ++ String.fromInt minutes
        ++ (if minutes == 1 then
                " minute."

            else
                " minutes."
           )
