module Evergreen.V3.Types exposing (..)

import Browser
import Browser.Navigation
import Date
import Dict
import Lamdera
import Set
import Time
import Url


type Auth
    = Checking
    | FirstRun
    | Locked
    | Unlocked


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


type alias DayEntry =
    { flow : Maybe Flow
    , moods : List Mood
    , symptoms : List Symptom
    , note : String
    }


type alias Settings =
    { name : String
    , cycleLength : Int
    , periodLength : Int
    }


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


type alias FrontendModel =
    { key : Browser.Navigation.Key
    , zone : Time.Zone
    , today : Maybe Date.Date
    , auth : Auth
    , passcode : String
    , passcodeConfirm : String
    , authError : Maybe String
    , days : Dict.Dict Int DayEntry
    , settings : Settings
    , page : Page
    , monthOffset : Int
    , editor : Maybe Editor
    , settingsForm : SettingsForm
    , notice : Maybe String
    }


type alias Credentials =
    { salt : String
    , hash : String
    }


type alias BackendModel =
    { credentials : Maybe Credentials
    , sessions : Set.Set Lamdera.SessionId
    , days : Dict.Dict Int DayEntry
    , settings : Settings
    , failedLogins : Int
    , lockedUntil : Int
    }


type FrontendMsg
    = UrlClicked Browser.UrlRequest
    | UrlChanged Url.Url
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


type ToBackend
    = Hello
    | SetupPasscode String
    | Login String
    | Logout
    | SaveDay Int DayEntry
    | DeleteDay Int
    | SaveSettings Settings
    | ChangePasscode String String


type BackendMsg
    = SetupAt Lamdera.SessionId Lamdera.ClientId String Time.Posix
    | LoginAt Lamdera.SessionId Lamdera.ClientId String Time.Posix
    | ChangePasscodeAt Lamdera.SessionId Lamdera.ClientId String String Time.Posix


type alias AppData =
    { days : Dict.Dict Int DayEntry
    , settings : Settings
    }


type ToFrontend
    = AskForSetup
    | AskForPasscode
    | Unlock AppData
    | AuthError String
    | DayChanged Int (Maybe DayEntry)
    | SettingsChanged Settings
    | PasscodeChangeResult (Result String ())
    | Lock
