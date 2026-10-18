module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Date exposing (Date)
import Dict exposing (Dict)
import Lamdera exposing (ClientId, SessionId)
import Set exposing (Set)
import Time
import Url exposing (Url)



-- DOMAIN


{-| Days are keyed by their Rata Die number (see `Date.toRataDie`).
-}
type alias DayEntry =
    { flow : Maybe Flow
    , moods : List Mood
    , symptoms : List Symptom
    , note : String
    }


type Flow
    = Spotting
    | Light
    | Medium
    | Heavy


type Mood
    = Happy
    | Calm
    | Sensitive
    | Irritable
    | Sad
    | Anxious


type Symptom
    = Cramps
    | Headache
    | Bloating
    | Fatigue
    | TenderBreasts
    | Acne
    | Cravings
    | BackPain
    | Nausea
    | TiredLegs
    | NervousStomach


type alias Settings =
    { name : String
    , cycleLength : Int
    , periodLength : Int
    }


type alias AppData =
    { days : Dict Int DayEntry
    , settings : Settings
    }


emptyEntry : DayEntry
emptyEntry =
    { flow = Nothing, moods = [], symptoms = [], note = "" }


defaultSettings : Settings
defaultSettings =
    { name = "", cycleLength = 28, periodLength = 5 }



-- FRONTEND


type alias FrontendModel =
    { key : Key
    , zone : Time.Zone
    , today : Maybe Date
    , auth : Auth
    , passcode : String
    , passcodeConfirm : String
    , authError : Maybe String
    , days : Dict Int DayEntry
    , settings : Settings
    , page : Page
    , monthOffset : Int
    , editor : Maybe Editor
    , settingsForm : SettingsForm
    , notice : Maybe String
    }


type Auth
    = Checking
    | FirstRun
    | Locked
    | Unlocked


type Page
    = TodayPage
    | CalendarPage
    | InsightsPage
    | SettingsPage


type alias Editor =
    { day : Int
    , entry : DayEntry
    }


type alias SettingsForm =
    { name : String
    , cycleLength : String
    , periodLength : String
    , currentPasscode : String
    , newPasscode : String
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | GotTime Time.Zone Time.Posix
    | Tick Time.Posix
    | PasscodeInput String
    | PasscodeConfirmInput String
    | SubmitSetup
    | SubmitLogin
    | GoTo Page
    | ChangeMonth Int
    | OpenDay Int
    | CloseEditor
    | SetFlow (Maybe Flow)
    | ToggleMood Mood
    | ToggleSymptom Symptom
    | NoteInput String
    | SaveEditor
    | ClearEditorDay
    | LogPeriodToday
    | SettingsNameInput String
    | SettingsCycleInput String
    | SettingsPeriodInput String
    | SubmitSettings
    | CurrentPasscodeInput String
    | NewPasscodeInput String
    | SubmitPasscodeChange
    | LogOut
    | DismissNotice String
    | NoOpFrontendMsg



-- BACKEND


type alias BackendModel =
    { credentials : Maybe Credentials
    , sessions : Set SessionId
    , days : Dict Int DayEntry
    , settings : Settings
    , failedLogins : Int
    , lockedUntil : Int
    }


type alias Credentials =
    { salt : String
    , hash : String
    }


type BackendMsg
    = SetupAt SessionId ClientId String Time.Posix
    | LoginAt SessionId ClientId String Time.Posix
    | ChangePasscodeAt SessionId ClientId String String Time.Posix



-- WIRE


type ToBackend
    = Hello
    | SetupPasscode String
    | Login String
    | Logout
    | SaveDay Int DayEntry
    | DeleteDay Int
    | SaveSettings Settings
    | ChangePasscode String String


type ToFrontend
    = AskForSetup
    | AskForPasscode
    | Unlock AppData
    | AuthError String
    | DayChanged Int (Maybe DayEntry)
    | SettingsChanged Settings
    | PasscodeChangeResult (Result String ())
    | Lock
