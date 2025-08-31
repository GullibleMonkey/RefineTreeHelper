; ================================================================================
; REVOLUTION IDLE HELPER v1.2 - Revolution Idle Automation Script
; ================================================================================
; Description: Automation suite for Revolution Idle including minerals, unity, and utilities
; Author: GullibleMonkey
; Compatible with AutoHotkey v2.0
; Usage: F5 to start/stop, F10 to compact, Esc to exit
; ================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
#Warn

; ================================================================================
; INITIALIZATION
; ================================================================================

SendMode "Input"
SetMouseDelay 0
SetKeyDelay 0, 0
CoordMode "Mouse", "Screen"

; Configure DPI handling for high DPI displays to prevent font scaling issues
try {
    ; Try system DPI unaware (prevents Windows from scaling the application)
    DllCall("SetProcessDpiAwarenessContext", "ptr", -2)  ; DPI_AWARENESS_CONTEXT_SYSTEM_UNAWARE
} catch {
    try {
        ; Fallback: completely disable DPI awareness
        DllCall("User32.dll\SetProcessDPIAware")
    } catch {
        ; No DPI handling available - will use system default
    }
}

; ================================================================================
; CONSTANTS
; ================================================================================

class Constants {
    ; Timing constants
    static REDISTRIBUTION_WAIT := 400
    static UNITE_DIALOG_WAIT := 800
    static TAB_TRANSITION_WAIT := 250
    static SCREENSHOT_CLEANUP_HOURS := 2
    static SCREENSHOT_MAX_FILES := 10
    static UI_UPDATE_INTERVAL := 250
    static STATE_LOCK_WAIT := 1
    
    ; UI Layout Constants - Standardized spacing system
    static MAX_MACRO_COUNT := 9
    static RUNNING_WINDOW_TRANSPARENCY := 180
    
    ; Base spacing units
    static UI_PAD := 16              ; Section padding
    static UI_GAP := 10              ; Standard element gap
    static UI_ROW_GAP := 12          ; Between button rows within sections  
    static UI_SECTION_GAP := 12      ; Between sections
    static UI_INPUT_GAP := 15        ; Label-to-input spacing
    static UI_HEADER_SPACING := 32   ; After section headers
    
    ; Element dimensions
    static UI_BUTTON_HEIGHT := 34    ; Standard button height
    static UI_INPUT_HEIGHT := 30     ; Input field height
    static UI_LABEL_OFFSET := 4      ; Label vertical offset for alignment
    
    ; Standardized button widths - configured for text fit
    static UI_BTN_TINY := 110        ; Very short text (Standard, Quick, Long) - more padding
    static UI_BTN_SMALL := 95        ; Game state buttons
    static UI_BTN_MEDIUM := 140      ; Medium text buttons
    static UI_BTN_LARGE := 180       ; Longer text buttons  
    static UI_BTN_XLARGE := 220      ; Extra long text buttons
    static UI_BTN_FULL := 280        ; Full-width single buttons
    static UI_BTN_UNLOCKS := 320     ; Unlockables section only
    
    
    ; File system constants
    static MAX_LOG_SIZE := 1048576  ; 1MB
    static CONFIG_BACKUP_COUNT := 3
    
    ; Validation ranges
    static MIN_COORDINATE := 0
    static MAX_COORDINATE := 3840  ; 4K display width
    static MIN_DELAY := 10
    static MAX_DELAY := 10000
    static MIN_THRESHOLD := 0
    static MAX_THRESHOLD := 255
}

; ================================================================================
; CONFIGURATION
; ================================================================================

class Config {
    ; Target game process name
    static TARGET_PROCESS := "Revolution Idle.exe"
    
    ; Configuration file path for saving user preferences
    static CONFIG_FILE := A_ScriptDir "\RevolutionIdleHelper_v1.2.ini"
    
    ; UI color scheme
    static COLOR_WHITE := 0xFFFFFF
    static COLOR_BLACK := 0x000000
    static COLOR_GRAY := 0x808080
    
    ; How often to update the UI display (in milliseconds)
    static UI_UPDATE_INTERVAL := 250
    
    ; Order in which to level up weapons
    static weaponOrder := ["sword", "knuckle", "axe", "spear", "bow"]
}

; ================================================================================
; GLOBAL STATE MANAGEMENT
; ================================================================================

class State {
    ; Macro execution state flags
    static isRunning := false        ; Is the macro currently running?
    static isStarting := false       ; Is the macro in the process of starting?
    static isStopping := false       ; Is the macro in the process of stopping?
    static isLocked := false         ; Is the macro locked (prevents multiple starts)?
    static queuedStart := false      ; Is there a queued start request?
    static stateLock := false        ; Internal lock for atomic state operations
    
    ; Atomic state transition to prevent race conditions
    static SetSafeState(newRunning, newStarting := false, newStopping := false) {
        ; Wait for any ongoing state change to complete
        while State.stateLock
            Sleep 1
        
        ; Lock state changes
        State.stateLock := true
        
        try {
            State.isRunning := newRunning
            State.isStarting := newStarting
            State.isStopping := newStopping
            State.isLocked := newRunning || newStarting || newStopping  ; Set locked state based on activity
            State.queuedStart := false                                  ; Clear any queued start request
        } finally {
            ; Always release lock
            State.stateLock := false
        }
    }
    
    ; Performance statistics
    static cycleCount := 0           ; Number of completed refine cycles
    static autoUnityCount := 0       ; Number of completed Auto Unity cycles (max 76)
    static startTime := 0            ; When the current macro run started
    static currentMacro := "standard"  ; Active macro type (default: standard)
    static gameState := "early"      ; Game progression state (default: early)
    static cycleTimes := []          ; Array of recent cycle completion times
    static lastCycleEnd := 0        ; Timestamp of last cycle completion
    
    ; User-configurable settings with defaults
    static mineralLevel := "999"     ; Highest mineral level to spawn
    static mergeWaitTime := "5000"  ; Milliseconds to wait for minerals to merge (default: 5000)
    static microDelayMs := 25        ; Small delay between actions (default: 25)
    static timewarpInterval := "1000" ; Time warp burst interval (default: 1000ms)
    static exploitWaitTime := "5000"  ; Exploit wait time (default: 5000ms)
    static bwThreshold := 128        ; Black/white threshold for screenshot processing
    
    ; Custom game state values
    static customSpawnReps := "4"    ; Custom spawn repetitions
    static customPolishReps := "1"   ; Custom polish repetitions
    static autoUnityMaxReps := "24"   ; Auto Unity maximum repetitions
    static zodiacRedistributionWait := "200"  ; Zodiac redistribution wait time (ms)
    
    ; Fine Settings toggles (true = enabled/auto, false = disabled/no auto)
    static autoRefining := true      ; Auto refining enabled (default: true)
    static autoRftUpgrade := false    ; Auto RfT upgrade enabled (default: false)
    static allWeaponsPolish := false ; Polish all weapons vs sword only (default: false)
    
    ; Automation Unlockables (false = locked/manual, true = unlocked/auto)
    static autospawnUnlocked := false     ; Autospawn feature unlocked (default: false)
    static automergeUnlocked := false     ; Automerge feature unlocked (default: false)
    static autoMaxLevelUnlocked := false  ; Auto max level upgrade unlocked (default: false)
    static autoWeaponPolishUnlocked := false ; Auto weapon polish unlocked (default: false)
    
    ; Unity Parameters (zodiac element selection)
    static zodiacEarth := true            ; Earth zodiac element selected (default: true)
    static zodiacFire := true             ; Fire zodiac element selected (default: true)
    static zodiacWind := true             ; Wind zodiac element selected (default: true)
    static zodiacWater := true           ; Water zodiac element selected (default: true)
    static currentZodiacIndex := 0        ; Current zodiac index for cycling
    static timeWarpWaitTime := "10000"     ; Time warp wait time in milliseconds (default: 10000)
    static timeWarpReps := "1"            ; Number of time warp loops before uniting (default: 1)
    static timeWarpMinutesToSpend := "10"  ; Time warp minutes to spend (default: 10)
    
    ; UI section visibility states
    ; Section states - supports nested sections with dot notation
    static sectionStates := Map(
        ; Hierarchical structure matching .ini file organization
        "refining", false,
        "refining.macros", true,
        "refining.statistics", true,
        "refining.parameters", false,
        "refining.parameters.gamestate", true,
        "refining.parameters.finesettings", true,
        "refining.parameters.unlockables", true,
        "refining.parameters.variables", true,
        
        "unity", false,
        "unity.macros", true,
        "unity.parameters", false,
        "unity.parameters.zodiac", true,
        "unity.parameters.timewarp", true,
        
        "other", false,
        "other.macros", true,
        "other.parameters", false,
        "other.coordinates", false,
        "other.info", false,
        
        ; Legacy sections (for migration compatibility)
        "macro", true,
        "gamestate", true,
        "finesettings", true,
        "unlockables", true,
        "variables", true,
        "unityparameters", true,
        "statistics", true,
        "info", true
    )
    
    ; Screenshot capture settings
    static lastScreenshotPath := ""
    static captureRect := {x: 1017, y: 386, w: 470, h: 49}
    static captureMode := "screen"
    
    ; Coordinate picker state
    static isPickingCoordinate := false
    static currentCoordinateName := ""
    static coordinatePickerHotkey := ""
    
    ; Game coordinates - moved from Config class for dynamic management
    static coords := Map(
        ; Mineral spawning buttons
        "spawn", [809, 1454],
        "spawnLevel", [879, 1348],
        "maxLevel", [1100, 650],
        "autospawn", [960, 1251],
        
        ; Weapon polishing menu
        "polishOpen", [1223, 1452],
        "polishPrestige", [1231, 550],
        "polishPrestigeConfirm", [1514, 933],
        "polishLevelUp", [1694, 1386],
        "polishClose", [1919, 421],
        
        ; Weapon selection buttons
        "sword", [111, 1000],
        "axe", [400, 1000],
        "spear", [700, 1000],
        "bow", [1000, 1000],
        "knuckle", [1400, 1000],
        
        ; Refining menu
        "refineOpen", [1730, 1456],
        "refinePrestige", [1695, 591],
        "refinePrestigeConfirm", [1497, 967],
        "refineClose", [79, 383],
        
        ; Game tabs
        "timeFluxTab", [2100, 820],
        "attacksTab", [2100, 640],
        "shopTab", [2100, 1300],
        "automationTab", [2100, 730],
        "unityTab", [2100, 540],
        
        ; Automation controls
        "automerge", [1852, 249],
        
        ; Time warp controls
        "timewarpStart", [785, 1055],
        "timewarpStop", [1200, 895],
        "timeWarpMinutesSpend", [430, 1060],
        
        ; Shop actions
        "buyTimeFlux", [1200, 1400],
        "purchaseConfirm", [1500, 850],
        
        ; Unity actions
        "unite", [1000, 1450],
        "uniteConfirm1", [1200, 750],
        "uniteConfirm2", [1500, 900],
        "zodiacWater", [1200, 1100],
        "zodiacWind", [1500, 750],
        "zodiacEarth", [1200, 400],
        "zodiacFire", [850, 750],
        
        ; Zodiac Redistribution actions
        "redistributionTopBox", [450, 1030],
        "redistributionBottomBox", [450, 1430],
        "redistribute", [450, 1290],
        
        ; Empty space for endgame exploit
        "emptySpace", [833, 1217]
    )
}

; ================================================================================
; UI COMPONENTS
; ================================================================================

class UI {
    ; Main UI windows
    static gui := 0              ; Main HUD window
    static compactGui := 0       ; Compact mode window (small eye icon)
    static isVisible := true     ; Is the main HUD visible?
    static isCompact := false    ; Is the HUD in compact mode?
    
    ; GDI+ token for screenshot functionality
    static gdiToken := 0
    
    ; UI update optimization
    static needsUpdate := false
    static lastUpdateTime := 0
    static updateInterval := Constants.UI_UPDATE_INTERVAL
    
    ; Mark UI as needing update
    static MarkDirty() {
        UI.needsUpdate := true
    }
    
    ; UI state tracking
    static buttonStates := Map()      ; Track button active states
    static sectionContents := Map()   ; Store controls for each collapsible section
    
    ; Header controls
    static header := 0
    static titleText := 0
    static headerLeft := 0
    static headerRight := 0
    static btnEye := 0        ; Compact mode toggle
    static btnClose := 0      ; Exit button
    static btnStartStop := 0  ; Main start/stop button
    
    ; Section headers for collapsible sections
    static sectionHeaders := Map()
    static sectionBorders := Map()  ; Track border elements for each section
    
    ; Macro selection buttons
    static btnMacroStandard := 0
    static btnMacroQuick := 0
    static btnMacroLong := 0
    static btnMacroEndgame := 0
    static btnMacroTimeWarp := 0
    static btnMacroAutoClicker := 0
    static btnMacroTimeFluxBuy := 0
    static btnMacroAutoUnity := 0
    static btnMacroZodiacRedistribution := 0
    
    ; Game state selection buttons
    static btnStateEarly := 0
    static btnStateMid := 0
    static btnStateLate := 0
    static btnStateCustom := 0
    static inputCustomSpawn := 0
    static inputCustomPolish := 0
    
    ; Fine Settings buttons
    static btnToggleRefining := 0
    static btnToggleRftUpgrade := 0
    static btnTogglePolishMode := 0
    
    ; Automation Unlockables buttons
    static btnToggleAutospawn := 0
    static btnToggleAutomerge := 0
    static btnToggleAutoMaxLevel := 0
    static btnToggleAutoWeaponPolish := 0
    
    ; Variable input controls
    static lblMineralLevel := 0
    static inputMineralLevel := 0
    static lblMergeWait := 0
    static inputMergeWait := 0
    static lblMicroDelay := 0
    static inputMicroDelay := 0
    static lblTimewarp := 0
    static inputTimewarp := 0
    static lblTimeWarpMinutesToSpend := 0
    static inputTimeWarpMinutesToSpend := 0
    static lblExploitWait := 0
    static inputExploitWait := 0
    
    ; Unity Parameters buttons
    static btnZodiacEarth := 0
    static btnZodiacFire := 0
    static btnZodiacWind := 0
    static btnZodiacWater := 0
    
    ; Unity Parameters inputs
    static lblTimeWarpWaitTime := 0
    static inputTimeWarpWaitTime := 0
    static lblTimeWarpReps := 0
    static inputTimeWarpReps := 0
    static lblAutoUnityMaxReps := 0
    static inputAutoUnityMaxReps := 0
    static lblZodiacRedistributionWait := 0
    static inputZodiacRedistributionWait := 0
    
    ; Statistics display controls
    static imgPreview := 0
    static lblStatistics := 0
    static lblCycleTime := 0
    
    ; Info section control
    static lblInfo := 0
    
    ; Coordinate ListView control
    static coordListView := 0
    static headerHwnd := 0
    
    ; Layout constants
    static hudW := 580     ; HUD window width
    
    ; UI spacing - now using standardized constants
    static pad := Constants.UI_PAD
    static gap := Constants.UI_GAP
    static btnH := Constants.UI_BUTTON_HEIGHT
    static hdrH := 42      ; Header height for UI elements
    static rowGap := Constants.UI_ROW_GAP
    static sectionGap := Constants.UI_SECTION_GAP
}

; ================================================================================
; UTILITY FUNCTIONS
; ================================================================================

class Util {
    ; Convert milliseconds to readable time format (HH:MM:SS:X)
    static FormatTime(ms) {
        sec := Floor(ms / 1000)
        h := Floor(sec / 3600)
        rem := sec - (h * 3600)
        m := Floor(rem / 60)
        s := rem - (m * 60)
        ds := Floor((ms - (sec * 1000)) / 100)
        return Format("{:02d}:{:02d}:{:02d}:{:01d}", h, m, s, ds)
    }
    
    ; Sleep function that can be interrupted if macro stops
    static Sleep(ms) {
        remain := ms
        step := (ms >= 2000) ? 50 : (ms >= 500 ? 25 : 10)
        while (remain > 0) {
            if !State.isRunning
                return
            s := (remain < step) ? remain : step
            Sleep s
            remain -= s
        }
    }
    
    ; Focus the game window, optionally forcing focus
    static FocusGame(force := true) {
        hwnd := WinExist("ahk_exe " Config.TARGET_PROCESS)
        if !hwnd
            return false
        if force || !WinActive("ahk_id " hwnd) {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 0.8
        }
        return WinActive("ahk_id " hwnd)
    }
    
    ; Check if the game window is not active
    static IsGameBlocked() {
        return !WinActive("ahk_exe " Config.TARGET_PROCESS)
    }
}

; ================================================================================
; CONFIGURATION MANAGEMENT
; ================================================================================

class ConfigManager {
    ; Load settings from INI file
    static Load() {
        ini := Config.CONFIG_FILE
        
        ; Load macro and game state settings with validation
        State.currentMacro := Validator.ValidateMacro(IniRead(ini, "Settings", "Macro", "standard"))
        State.gameState := Validator.ValidateGameState(IniRead(ini, "Settings", "GameState", "early"))
        State.mineralLevel := Validator.ValidateString(IniRead(ini, "Settings", "MineralLevel", "999"), 10, "999")
        State.mergeWaitTime := Validator.ValidateString(IniRead(ini, "Settings", "MergeWaitTime", "5000"), 10, "5000")
        State.bwThreshold := Validator.ValidateNumericRange(IniRead(ini, "Settings", "BWThreshold", 128) + 0, Constants.MIN_THRESHOLD, Constants.MAX_THRESHOLD, 128)
        State.timewarpInterval := Validator.ValidateString(IniRead(ini, "Settings", "TimewarpInterval", "1000"), 10, "1000")
        State.exploitWaitTime := Validator.ValidateString(IniRead(ini, "Settings", "ExploitWaitTime", "5000"), 10, "5000")
        
        ; Load custom game state values with validation
        State.customSpawnReps := Validator.ValidateString(IniRead(ini, "Settings", "CustomSpawnReps", "4"), 5, "4")
        State.customPolishReps := Validator.ValidateString(IniRead(ini, "Settings", "CustomPolishReps", "1"), 5, "1")
        
        ; Load delay setting with validation and backward compatibility
        State.microDelayMs := Validator.ValidateNumericRange(IniRead(ini, "Settings", "MicroDelayMs", 25) + 0, Constants.MIN_DELAY, Constants.MAX_DELAY, 25)
        oldDelay := IniRead(ini, "Settings", "MICRO_DELAY", "")
        if (oldDelay != "" && State.microDelayMs = 25) {
            State.microDelayMs := Validator.ValidateNumericRange(oldDelay + 0, Constants.MIN_DELAY, Constants.MAX_DELAY, 25)
        }
        
        ; Load Fine Settings toggles with validation (all default to true)
        State.autoRefining := Validator.ValidateBoolean(IniRead(ini, "FineSettings", "AutoRefining", 1))
        State.autoRftUpgrade := Validator.ValidateBoolean(IniRead(ini, "FineSettings", "AutoRftUpgrade", 0))
        State.allWeaponsPolish := Validator.ValidateBoolean(IniRead(ini, "FineSettings", "AllWeaponsPolish", 0))
        
        ; Load Automation Unlockables (all default to false)
        State.autospawnUnlocked := (IniRead(ini, "Unlockables", "AutospawnUnlocked", 0) + 0) ? true : false
        State.automergeUnlocked := (IniRead(ini, "Unlockables", "AutomergeUnlocked", 0) + 0) ? true : false
        State.autoMaxLevelUnlocked := (IniRead(ini, "Unlockables", "AutoMaxLevelUnlocked", 0) + 0) ? true : false
        State.autoWeaponPolishUnlocked := (IniRead(ini, "Unlockables", "AutoWeaponPolishUnlocked", 0) + 0) ? true : false
        
        ; Load Unity Parameters (all default to false)
        State.zodiacEarth := (IniRead(ini, "UnityParameters", "ZodiacEarth", 1) + 0) ? true : false
        State.zodiacFire := (IniRead(ini, "UnityParameters", "ZodiacFire", 1) + 0) ? true : false
        State.zodiacWind := (IniRead(ini, "UnityParameters", "ZodiacWind", 0) + 0) ? true : false
        State.zodiacWater := (IniRead(ini, "UnityParameters", "ZodiacWater", 0) + 0) ? true : false
        State.timeWarpWaitTime := IniRead(ini, "UnityParameters", "TimeWarpWaitTime", "5000")
        State.timeWarpReps := IniRead(ini, "UnityParameters", "TimeWarpReps", "1")
        State.timeWarpMinutesToSpend := IniRead(ini, "UnityParameters", "TimeWarpMinutesToSpend", "10")
        State.autoUnityMaxReps := IniRead(ini, "UnityParameters", "AutoUnityMaxReps", "24")
        State.zodiacRedistributionWait := IniRead(ini, "UnityParameters", "ZodiacRedistributionWait", "200")
        
        ; Load section visibility states - iterate through all defined sections
        for section, defaultState in State.sectionStates {
            State.sectionStates[section] := (IniRead(ini, "Sections", section, defaultState ? 1 : 0) + 0) ? true : false
        }
        
        ; Load screenshot capture settings
        State.captureRect.x := IniRead(ini, "Capture", "X", State.captureRect.x) + 0
        State.captureRect.y := IniRead(ini, "Capture", "Y", State.captureRect.y) + 0
        State.captureRect.w := IniRead(ini, "Capture", "W", State.captureRect.w) + 0
        State.captureRect.h := IniRead(ini, "Capture", "H", State.captureRect.h) + 0
        State.captureMode := IniRead(ini, "Capture", "Mode", State.captureMode)
        
        ; Load coordinates - iterate through all defined coordinates
        for coordName, defaultCoords in State.coords {
            x := IniRead(ini, "Coordinates", coordName . "_X", defaultCoords[1]) + 0
            y := IniRead(ini, "Coordinates", coordName . "_Y", defaultCoords[2]) + 0
            State.coords[coordName] := [x, y]
        }
    }
    
    ; Save settings to INI file
    static Save() {
        ini := Config.CONFIG_FILE
        
        ; Save window position if GUI exists
        if UI.gui && IsObject(UI.gui) {
            try {
                x := 0, y := 0
                WinGetPos &x, &y, , , "ahk_id " UI.gui.Hwnd
                IniWrite x, ini, "UI", "X"
                IniWrite y, ini, "UI", "Y"
            }
        }
        
        ; Save all settings
        IniWrite State.currentMacro, ini, "Settings", "Macro"
        IniWrite State.gameState, ini, "Settings", "GameState"
        IniWrite State.mineralLevel, ini, "Settings", "MineralLevel"
        IniWrite State.mergeWaitTime, ini, "Settings", "MergeWaitTime"
        IniWrite State.microDelayMs, ini, "Settings", "MicroDelayMs"
        IniWrite State.bwThreshold, ini, "Settings", "BWThreshold"
        IniWrite State.timewarpInterval, ini, "Settings", "TimewarpInterval"
        IniWrite State.exploitWaitTime, ini, "Settings", "ExploitWaitTime"
        IniWrite State.customSpawnReps, ini, "Settings", "CustomSpawnReps"
        IniWrite State.customPolishReps, ini, "Settings", "CustomPolishReps"
        
        ; Save Fine Settings
        IniWrite (State.autoRefining ? 1 : 0), ini, "FineSettings", "AutoRefining"
        IniWrite (State.autoRftUpgrade ? 1 : 0), ini, "FineSettings", "AutoRftUpgrade"
        IniWrite (State.allWeaponsPolish ? 1 : 0), ini, "FineSettings", "AllWeaponsPolish"
        
        ; Save Automation Unlockables
        IniWrite (State.autospawnUnlocked ? 1 : 0), ini, "Unlockables", "AutospawnUnlocked"
        IniWrite (State.automergeUnlocked ? 1 : 0), ini, "Unlockables", "AutomergeUnlocked"
        IniWrite (State.autoMaxLevelUnlocked ? 1 : 0), ini, "Unlockables", "AutoMaxLevelUnlocked"
        IniWrite (State.autoWeaponPolishUnlocked ? 1 : 0), ini, "Unlockables", "AutoWeaponPolishUnlocked"
        
        ; Save Unity Parameters
        IniWrite (State.zodiacEarth ? 1 : 0), ini, "UnityParameters", "ZodiacEarth"
        IniWrite (State.zodiacFire ? 1 : 0), ini, "UnityParameters", "ZodiacFire"
        IniWrite (State.zodiacWind ? 1 : 0), ini, "UnityParameters", "ZodiacWind"
        IniWrite (State.zodiacWater ? 1 : 0), ini, "UnityParameters", "ZodiacWater"
        IniWrite State.timeWarpWaitTime, ini, "UnityParameters", "TimeWarpWaitTime"
        IniWrite State.timeWarpReps, ini, "UnityParameters", "TimeWarpReps"
        IniWrite State.timeWarpMinutesToSpend, ini, "UnityParameters", "TimeWarpMinutesToSpend"
        IniWrite State.autoUnityMaxReps, ini, "UnityParameters", "AutoUnityMaxReps"
        IniWrite State.zodiacRedistributionWait, ini, "UnityParameters", "ZodiacRedistributionWait"
        
        ; Save section states
        for section, isOpen in State.sectionStates {
            IniWrite (isOpen ? 1 : 0), ini, "Sections", section
        }
        
        ; Save capture settings
        IniWrite State.captureRect.x, ini, "Capture", "X"
        IniWrite State.captureRect.y, ini, "Capture", "Y"
        IniWrite State.captureRect.w, ini, "Capture", "W"
        IniWrite State.captureRect.h, ini, "Capture", "H"
        IniWrite State.captureMode, ini, "Capture", "Mode"
        
        ; Save coordinates
        for coordName, coords in State.coords {
            IniWrite coords[1], ini, "Coordinates", coordName . "_X"
            IniWrite coords[2], ini, "Coordinates", coordName . "_Y"
        }
    }
}

; ================================================================================
; ERROR HANDLING
; ================================================================================

class ErrorHandler {
    static logFile := A_ScriptDir "\RevolutionIdleHelper_errors.log"
    static maxLogSize := Constants.MAX_LOG_SIZE
    
    ; Log errors with timestamps
    static LogError(source, error, context := "") {
        try {
            timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            errorMsg := Format("{1} [{2}] {3}: {4}", timestamp, source, error.message, context)
            if context != ""
                errorMsg .= " (" context ")"
            errorMsg .= "`n"
            
            ; Check log file size and rotate if needed
            if FileExist(ErrorHandler.logFile) {
                logFile := FileOpen(ErrorHandler.logFile, "r")
                if logFile && logFile.Length > ErrorHandler.maxLogSize {
                    logFile.Close()
                    try FileMove ErrorHandler.logFile, ErrorHandler.logFile ".old"
                } else if logFile {
                    logFile.Close()
                }
            }
            
            FileAppend errorMsg, ErrorHandler.logFile
        } catch {
            ; Silent fail if logging fails
        }
    }
    
    ; Handle critical errors that should stop the script
    static HandleCriticalError(source, error, context := "") {
        ErrorHandler.LogError(source, error, context)
        State.SetSafeState(false)  ; Stop all operations
        if UI.gui && IsObject(UI.gui) {
            try UI.gui.Title := "Revolution Idle Helper v1.2 - ERROR: " error.message
        }
    }
}

; ================================================================================
; INPUT VALIDATION
; ================================================================================

class Validator {
    ; Validate numeric ranges with fallback defaults
    static ValidateNumericRange(value, min, max, defaultValue) {
        if !IsNumber(value) || value < min || value > max
            return defaultValue
        return Integer(value)
    }
    
    ; Validate coordinates
    static ValidateCoordinates(coords) {
        if !IsObject(coords) || coords.Length < 2
            return false
        return IsNumber(coords[1]) && IsNumber(coords[2]) && 
               coords[1] >= Constants.MIN_COORDINATE && coords[1] <= Constants.MAX_COORDINATE &&
               coords[2] >= Constants.MIN_COORDINATE && coords[2] <= Constants.MAX_COORDINATE
    }
    
    ; Validate macro name
    static ValidateMacro(value) {
        validMacros := ["standard", "quick", "long", "timewarp", "autoclicker", "endgame", "timefluxbuy", "autounity", "zodiacredistribution"]
        for macroName in validMacros {
            if macroName = value
                return value
        }
        return "standard"
    }
    
    ; Validate game state
    static ValidateGameState(value) {
        validStates := ["early", "mid", "late", "custom"]
        for stateName in validStates {
            if stateName = value
                return value
        }
        return "early"
    }
    
    ; Validate string input
    static ValidateString(value, maxLength := 100, defaultValue := "") {
        if (Type(value) != "String" || StrLen(value) > maxLength)
            return defaultValue
        return value
    }
    
    ; Validate boolean from INI (handles "1"/"0" strings)
    static ValidateBoolean(value) {
        if (Type(value) = "String")
            return (value = "1" || value = "true")
        return !!value
    }
}

; ================================================================================
; GAME ACTIONS
; ================================================================================

class Action {
    ; Click at a named coordinate from the State.coords map
    static Click(name) {
        if !State.isRunning || !State.coords.Has(name) || Util.IsGameBlocked()
            return false
        
        try {
            xy := State.coords[name]
            if !IsObject(xy) || xy.Length < 2 || !IsNumber(xy[1]) || !IsNumber(xy[2])
                return false
            Click xy[1], xy[2]
            Util.Sleep(State.microDelayMs)
            return true
        } catch Error as e {
            ErrorHandler.LogError("Action.Click", e, "Failed to click: " name)
            return false
        }
    }
    
    ; Type text into the game (selects all first)
    static Type(text) {
        if !State.isRunning || Util.IsGameBlocked()
            return false
        
        try {
            if (Type(text) != "String" || StrLen(text) = 0)
                return false
            Send "^a"  ; Select all
            Sleep 30
            SendText text
            Util.Sleep(State.microDelayMs)
            return true
        } catch Error as e {
            ErrorHandler.LogError("Action.Type", e, "Failed to type: " text)
            return false
        }
    }
    
    ; Spawn a single mineral
    static SpawnMineral() {
        Action.Click("spawn")
    }
    
    ; Level up mineral based on unlockable toggle
    static LevelUpMineral() {
        if (!State.autoMaxLevelUnlocked) {
            ; LOCKED mode: click max level first, then set level
            Action.Click("maxLevel")
            Util.Sleep(10)
            Action.Click("spawnLevel")
            Action.Type(State.mineralLevel)
        } else {
            ; UNLOCKED mode: directly set level
            Action.Click("spawnLevel")
            Action.Type(State.mineralLevel)
        }
    }
    
    ; Set mineral level to a specific value
    static SetMineralLevel(level) {
        Action.Click("spawnLevel")
        Action.Type(level)
    }
    
    ; Extended spawn for a duration
    static ExtendedSpawn(duration) {
        startTime := A_TickCount
        while ((A_TickCount - startTime) < duration && State.isRunning) {
            if (State.autospawnUnlocked) {
                ; Auto mode: use autospawn toggle
                Action.Click("autospawn")
                Action.LevelUpMineral()
                Action.Click("autospawn")
            } else {
                ; Manual mode: click repeatedly
                Action.LevelUpMineral()
                Action.Click("spawn")
            }
            Util.Sleep(State.microDelayMs)
        }
    }
    
    ; Polish weapons - either sword only or all weapons
    static PolishWeapons() {
        if !State.isRunning
            return
        
        ; Open polish menu and prestige
        Action.Click("polishOpen")
        Util.Sleep(State.microDelayMs)
        Action.Click("polishPrestige")
        Util.Sleep(State.microDelayMs)
        Action.Click("polishPrestigeConfirm")
        Util.Sleep(State.microDelayMs)
        
        ; Level weapons if NOT unlocked (manual mode)
        if (!State.autoWeaponPolishUnlocked) {
            if (!State.allWeaponsPolish) {
                ; Polish only sword
                Action.Click("sword")
                Util.Sleep(State.microDelayMs)
                Action.Click("polishLevelUp")
                Util.Sleep(State.microDelayMs)
            } else {
                ; Polish all weapons
                for weapon in Config.weaponOrder {
                    if !State.isRunning
                        return
                    Action.Click(weapon)
                    Util.Sleep(State.microDelayMs)
                    Action.Click("polishLevelUp")
                    Util.Sleep(State.microDelayMs)
                }
            }
        }
        
        ; Close polish menu
        Action.Click("polishClose")
        Util.Sleep(State.microDelayMs)
    }
    
    ; Toggle auto merge
    static AutoMerge() {
        if !State.automergeUnlocked
            return
        
        ; Open automation menu and toggle merge
        Action.Click("automationTab")
        Util.Sleep(State.microDelayMs)
        Action.Click("automerge")
        Util.Sleep(State.microDelayMs)
        Action.Click("automerge")
        Util.Sleep(State.microDelayMs)
        Action.Click("unityTab")
        Util.Sleep(State.microDelayMs)
    }
    
    ; Refine minerals and update statistics
    static Refine() {
        ; Skip if auto refining is disabled
        if !State.autoRefining
            return
        
        ; Open refine menu and prestige
        Action.Click("refineOpen")
        Util.Sleep(State.microDelayMs)
        Action.Click("refinePrestige")
        Util.Sleep(State.microDelayMs)
        Action.Click("refinePrestigeConfirm")
        Util.Sleep(State.microDelayMs)
        
        ; Buy RfT upgrade if enabled
        if (State.autoRftUpgrade) {
            Action.Click("refineOpen")
            Util.Sleep(State.microDelayMs)
        }
        
        ; Close refine menu
        Action.Click("refineClose")
        Util.Sleep(State.microDelayMs)
        
        ; Update cycle statistics
        if State.lastCycleEnd > 0 {
            cycleTime := A_TickCount - State.lastCycleEnd
            State.cycleTimes.Push(cycleTime)
            if State.cycleTimes.Length > 20
                State.cycleTimes.RemoveAt(1)
        }
        State.lastCycleEnd := A_TickCount
        
        State.cycleCount += 1
        UIManager.Update()
    }
    
    ; Drag from one named coordinate to another
    static Drag(fromName, toName) {
        if !State.isRunning || !State.coords.Has(fromName) || !State.coords.Has(toName) || Util.IsGameBlocked()
            return false
        
        try {
            fromXY := State.coords[fromName]
            toXY := State.coords[toName]
            
            ; Validate coordinates
            if !IsObject(fromXY) || !IsObject(toXY) || fromXY.Length < 2 || toXY.Length < 2
                return false
            if !IsNumber(fromXY[1]) || !IsNumber(fromXY[2]) || !IsNumber(toXY[1]) || !IsNumber(toXY[2])
                return false
            
            ; Try using SendInput for more reliable drag
            ; First click to ensure the element is selected
            Click fromXY[1], fromXY[2]
            Util.Sleep(State.microDelayMs)
            
            ; Use SendInput for drag operation
            SendInput "{LButton Down}"
            Util.Sleep(State.microDelayMs)
            
            ; Move to starting position while button is down
            MouseMove fromXY[1], fromXY[2], 0
            Util.Sleep(State.microDelayMs)
            
            ; Move to destination
            MouseMove toXY[1], toXY[2], 0
            Util.Sleep(State.microDelayMs)
            
            ; Release button
            SendInput "{LButton Up}"
            Util.Sleep(State.microDelayMs)
            
            Util.Sleep(State.microDelayMs)
            return true
        } catch Error as e {
            ; Ensure mouse button is released on error
            try SendInput "{LButton Up}"
            ErrorHandler.LogError("Action.Drag", e, "Failed drag: " fromName " to " toName)
            return false
        }
    }
}

; ================================================================================
; ACTION SEQUENCES
; ================================================================================

class Sequence {
    ; Get spawn and polish repetitions based on game state
    static GetRepetitions() {
        spawnReps := 4
        polishReps := 1
        
        switch State.gameState {
            case "early":
                spawnReps := 7
                polishReps := 3
            case "mid":
                spawnReps := 5
                polishReps := 2
            case "late":
                spawnReps := 4
                polishReps := 1
            case "custom":
                spawnReps := State.customSpawnReps + 0
                polishReps := State.customPolishReps + 0
        }
        
        return {spawn: spawnReps, polish: polishReps}
    }
    
    ; Basic spawn sequence: spawn and level up one mineral
    static BasicSpawn() {
        Action.SpawnMineral()
        Action.LevelUpMineral()
    }
    
    ; Spawn with polish - repetitions based on game state
    static SpawnWithPolish() {
        reps := Sequence.GetRepetitions()
        
        ; Execute spawn and polish cycles
        Loop reps.polish {
            Loop reps.spawn {
                if !State.isRunning
                    return
                Sequence.BasicSpawn()
            }
            if State.isRunning
                Action.PolishWeapons()
        }
    }
    
    ; Spawn only (no polish) - also affected by game state
    static SpawnOnly() {
        reps := Sequence.GetRepetitions()
        
        Loop reps.spawn {
            if !State.isRunning
                return
            Sequence.BasicSpawn()
        }
    }
    
    ; Extended spawn sequence
    static ExtendedSpawn(duration) {
        Action.ExtendedSpawn(duration)
    }
    
    ; Final merge sequence - also affected by game state
    static FinalMerge(duration) {
        reps := Sequence.GetRepetitions()
        
        Loop reps.spawn {
            if !State.isRunning
                return
            Sequence.BasicSpawn()
        }
        
        Sequence.ExtendedSpawn(duration)
        Action.AutoMerge()
    }
    
    ; Get merge wait time from user input
    static GetMergeWaitTime() {
        waitTime := State.mergeWaitTime = "" ? 10000 : (State.mergeWaitTime + 0)
        if waitTime <= 0
            waitTime := 5000
        return waitTime
    }
    
    ; Get time warp interval from user input
    static GetTimewarpInterval() {
        interval := State.timewarpInterval = "" ? 10000 : (State.timewarpInterval + 0)
        if interval <= 0
            interval := 75
        return interval
    }
    
    ; Get exploit wait time from user input
    static GetExploitWaitTime() {
        waitTime := State.exploitWaitTime = "" ? 500 : (State.exploitWaitTime + 0)
        if waitTime <= 0
            waitTime := 500
        return waitTime
    }
}

; ================================================================================
; MACRO DEFINITIONS
; ================================================================================

class Macro {
    ; Standard macro cycle - balanced approach
    static Standard() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            Screenshot.Capture()
        }
        
        if !State.isRunning
            return
        Sequence.SpawnWithPolish()
        
        if !State.isRunning
            return
        Sequence.FinalMerge(Sequence.GetMergeWaitTime())
        
        if !State.isRunning
            return
        Action.Refine()
    }
    
    ; Quick macro cycle - faster, less polishing
    static Quick() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            Screenshot.Capture()
        }
        
        if !State.isRunning
            return
        Sequence.SpawnWithPolish()
        
        if !State.isRunning
            return
        Sequence.SpawnOnly()
        
        if !State.isRunning
            return
        Action.Refine()
    }
    
    ; Long macro cycle - more thorough with extra polish
    static Long() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            Screenshot.Capture()
        }
        
        if !State.isRunning
            return
        Sequence.SpawnWithPolish()
        
        if !State.isRunning
            return
        Sequence.FinalMerge(Sequence.GetMergeWaitTime())
        
        if !State.isRunning
            return
        Action.PolishWeapons()
        
        if !State.isRunning
            return
        Sequence.FinalMerge(Sequence.GetMergeWaitTime())
        
        if !State.isRunning
            return
        Action.Refine()
    }
    
    ; Endgame exploit macro - special sequence for endgame
    static Endgame() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            Screenshot.Capture()
        }
        
        if !State.autoRefining {
            ; When Auto Refining is OFF - simple exploit loop
            if !State.isRunning
                return
            
            ; Spawn once
            Action.SpawnMineral()
            
            ; Inner loop: 10 level/spawn cycles
            Loop 10 {
                if !State.isRunning
                    return
                
                ; Level up, spawn, reset to level 1, spawn, wait
                Action.SetMineralLevel("999")
                Action.SpawnMineral()
                Action.SetMineralLevel(State.mineralLevel)
                Action.Click("emptySpace")
                Util.Sleep(Sequence.GetExploitWaitTime())
            }
        } else {
            ; When Auto Refining is ON - complex sequence
            
            ; Start with Quick macro
            if !State.isRunning
                return
            Sequence.SpawnWithPolish()
            
            if !State.isRunning
                return
            Sequence.SpawnOnly()
            
            ; Set to max level and enable autospawn/automerge if unlocked
            if !State.isRunning
                return
            Action.SetMineralLevel("999")
            
            if State.autospawnUnlocked {
                Action.Click("autospawn")  ; Turn on autospawn
            }
            if State.automergeUnlocked {
                Action.Click("automerge")  ; Turn on automerge
            }
            
            ; Wait for merge
            Util.Sleep(Sequence.GetMergeWaitTime())
            
            ; Turn off autospawn/automerge
            if State.autospawnUnlocked {
                Action.Click("autospawn")  ; Turn off autospawn
            }
            if State.automergeUnlocked {
                Action.Click("automerge")  ; Turn off automerge
            }
            
            ; 3x (exploit loop x5 followed by Polish)
            Loop 3 {
                if !State.isRunning
                    return
                
                ; 5 exploit loops
                Loop 5 {
                    if !State.isRunning
                        return
                    
                    ; Spawn once
                    Action.SpawnMineral()
                    
                    ; Inner loop: 10 level/spawn cycles
                    Loop 10 {
                        if !State.isRunning
                            return
                        
                        Action.SetMineralLevel("999")
                        Action.SpawnMineral()
                        Action.SetMineralLevel(State.mineralLevel)
                        Action.Click([833, 1217])
                        Util.Sleep(Sequence.GetExploitWaitTime())
                    }
                }
                
                ; Polish after 5 loops
                if State.isRunning
                    Action.PolishWeapons()
            }
            
            ; 1x (exploit loop x5 followed by Refining)
            if !State.isRunning
                return
            
            ; 5 exploit loops
            Loop 5 {
                if !State.isRunning
                    return
                
                ; Spawn once
                Action.SpawnMineral()
                
                ; Inner loop: 10 level/spawn cycles
                Loop 10 {
                    if !State.isRunning
                        return
                    
                    Action.SetMineralLevel("999")
                    Action.SpawnMineral()
                    Action.SetMineralLevel(State.mineralLevel)
                    Action.Click([833, 1217])
                    Util.Sleep(Sequence.GetExploitWaitTime())
                }
            }
            
            ; Refine at the end
            if State.isRunning
                Action.Refine()
        }
    }
    
    ; Time Warp Burst macro - toggles time warp on and off
    static TimeWarp() {
        ; Initial setup - click Time Flux tab and set minutes to spend (only once)
        if State.isRunning {
            ; Go to Time Flux Tab
            Action.Click("timeFluxTab")
            Util.Sleep(Constants.TAB_TRANSITION_WAIT)
            
            ; Click on the minutes to spend field and enter the value
            Action.Click("timeWarpMinutesSpend")
            Action.Type(State.timeWarpMinutesToSpend)
            
            Util.Sleep(State.microDelayMs)
        }
        
        ; Continue with the existing loop indefinitely
        while State.isRunning {
            if !State.isRunning
                return
            
            ; Start time warp
            Action.Click("timewarpStart")
            
            ; Wait for interval
            Util.Sleep(Sequence.GetTimewarpInterval())
            
            if !State.isRunning
                return
            
            ; Stop time warp (no second wait)
            Action.Click("timewarpStop")
        }
    }
    
    ; Simple autoclicker - clicks at mouse position
    static AutoClicker() {
        ; Continuously click at current mouse position
        while State.isRunning {
            ; Only click if game is active
            if !Util.IsGameBlocked() {
                Click
            }
            ; Small delay between clicks
            Util.Sleep(State.microDelayMs)
        }
    }
    
    ; Time Flux Buy macro - clicks shop once, then loops buy and confirm
    static TimeFluxBuy() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            
            ; Go to Shop tab only once
            Action.Click("shopTab")
            Util.Sleep(State.microDelayMs)
            
            ; Loop buying Time Flux while running
            while State.isRunning {
                ; Buy Time Flux
                Action.Click("buyTimeFlux")
                Util.Sleep(State.microDelayMs)
                
                ; Confirm purchase
                Action.Click("purchaseConfirm")
                Util.Sleep(State.microDelayMs)
            }
        }
    }
    
    ; Zodiac Redistribution macro - drag points from bottom to top
    static ZodiacRedistribution() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            
            ; Click Redistribute button
            Action.Click("redistribute")
            
            ; Click bottom redistribution box
            Action.Click("redistributionBottomBox")
            Util.Sleep(State.zodiacRedistributionWait + 0)  ; Wait after clicking bottom box (before dragging)
            
            ; Try drag operation
            Action.Drag("redistributionBottomBox", "redistributionTopBox")
            
            ; Alternative: if drag doesn't work, try clicking top box directly
            Util.Sleep(State.microDelayMs)
            Action.Click("redistributionTopBox")
            
            Util.Sleep(State.microDelayMs)
        }
    }
    
    ; Auto Unity macro - complex sequence with zodiac cycling
    static AutoUnity() {
        if State.isRunning {
            Util.Sleep(State.microDelayMs)
            
            ; Go to Time Flux Tab
            Action.Click("timeFluxTab")
            Util.Sleep(Constants.TAB_TRANSITION_WAIT)  ; Wait for Time Flux tab to load
            
            ; Get time warp reps count
            reps := State.timeWarpReps + 0
            if (reps <= 0)
                reps := 1
            
            ; Perform time warp loops
            Loop reps {
                if !State.isRunning
                    break
                    
                ; Click Time Warp Start
                Action.Click("timewarpStart")
                Util.Sleep(State.timeWarpWaitTime + 0)
                
                ; Click Time Warp Stop
                Action.Click("timewarpStop")
                Util.Sleep(Constants.TAB_TRANSITION_WAIT)  ; Wait after stopping time warp
            }
            
            ; Go to Attacks tab
            Action.Click("attacksTab")
            Util.Sleep(State.microDelayMs)
            
            ; Click Unite
            Action.Click("unite")
            Util.Sleep(Constants.UNITE_DIALOG_WAIT)  ; Wait for Unite dialog to appear
            
            ; Click selected zodiac (cycle through selected ones)
            zodiacType := Macro.GetNextZodiac()
            if (zodiacType != "") {
                Action.Click(zodiacType)
                Util.Sleep(State.microDelayMs)
                
                ; Click Unite Confirmation 1
                Action.Click("uniteConfirm1")
                Util.Sleep(State.microDelayMs)
                
                ; Click Unite Confirmation 2
                Action.Click("uniteConfirm2")
                Util.Sleep(State.microDelayMs)
            }
            
            ; Wait in Attacks tab before next macro cycle
            Util.Sleep(1000)
        }
    }
    
    ; Helper function to get next zodiac in cycle
    static GetNextZodiac() {
        ; Build array of selected zodiacs in order: Fire -> Earth -> Wind -> Water
        selectedZodiacs := []
        if State.zodiacFire
            selectedZodiacs.Push("zodiacFire")
        if State.zodiacEarth
            selectedZodiacs.Push("zodiacEarth")
        if State.zodiacWind
            selectedZodiacs.Push("zodiacWind")
        if State.zodiacWater
            selectedZodiacs.Push("zodiacWater")
        
        if selectedZodiacs.Length = 0
            return ""
        
        ; Get current zodiac and advance to next
        State.currentZodiacIndex++
        if State.currentZodiacIndex > selectedZodiacs.Length
            State.currentZodiacIndex := 1
            
        return selectedZodiacs[State.currentZodiacIndex]
    }
}

; ================================================================================
; SCREENSHOT MANAGEMENT
; ================================================================================

class Screenshot {
    ; Initialize GDI+ for screenshot functionality
    static InitGDI() {
        if UI.gdiToken
            return
        
        ; Load GDI+ library
        h := DllCall("LoadLibrary", "str", "gdiplus.dll", "ptr")
        if !h
            throw Error("Failed to load gdiplus.dll")
        
        ; Start GDI+
        si := Buffer(16, 0)
        NumPut("UInt", 1, si, 0)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
        UI.gdiToken := token
    }
    
    ; Capture screenshot of game statistics
    static Capture() {
        Screenshot.InitGDI()
        
        ; Find game window
        hwnd := WinExist("ahk_exe " Config.TARGET_PROCESS)
        if !hwnd
            return
        
        ; Generate unique filename with timestamp
        timestamp := A_Now
        filename := A_Temp "\refine_shot_" timestamp ".png"
        
        ; Delete old file if exists
        if FileExist(filename)
            FileDelete(filename)
        
        ; Capture based on mode (screen or window)
        rect := State.captureRect
        if (State.captureMode = "screen") {
            Screenshot.CaptureRect(rect.x, rect.y, rect.w, rect.h, filename)
        } else {
            Screenshot.CaptureWindow(hwnd, rect.x, rect.y, rect.w, rect.h, filename)
        }
        
        ; Wait for file to be written
        Sleep 50
        
        ; Update UI with screenshot
        if FileExist(filename) {
            State.lastScreenshotPath := filename
            if UI.imgPreview && IsObject(UI.imgPreview) {
                try {
                    UI.imgPreview.Value := filename
                }
            }
        }
        
        ; Clean up old screenshots
        Screenshot.CleanOldFiles()
    }
    
    ; Capture a rectangular area of the screen
    static CaptureRect(x, y, w, h, outPath) {
        ; Create device context and bitmap
        hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
        hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
        DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h, 
                "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020)
        
        ; Convert to GDI+ bitmap and apply threshold
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap)
        Screenshot.ApplyThreshold(pBitmap, State.bwThreshold)
        
        ; Save as PNG
        clsid := Screenshot.GetPngCLSID()
        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", outPath, "ptr", clsid, "ptr", 0)
        
        ; Cleanup
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    }
    
    ; Capture a rectangular area of a specific window
    static CaptureWindow(hwnd, rx, ry, rw, rh, outPath) {
        rc := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
        pt := Buffer(8, 0)
        DllCall("ClientToScreen", "ptr", hwnd, "ptr", pt)
        wx := NumGet(pt, 0, "int")
        wy := NumGet(pt, 4, "int")
        Screenshot.CaptureRect(wx + rx, wy + ry, rw, rh, outPath)
    }
    
    ; Apply black/white threshold to image for better OCR
    static ApplyThreshold(pBitmap, threshold := 128) {
        w := 0, h := 0
        DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &w)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &h)
        
        rect := Buffer(16, 0)
        NumPut("Int", 0, rect, 0)
        NumPut("Int", 0, rect, 4)
        NumPut("Int", w, rect, 8)
        NumPut("Int", h, rect, 12)
        
        bd := Buffer((A_PtrSize = 8) ? 32 : 24, 0)
        DllCall("gdiplus\GdipBitmapLockBits", "ptr", pBitmap, "ptr", rect, 
                "uint", 3, "int", 0x26200A, "ptr", bd)
        
        stride := NumGet(bd, 8, "Int")
        scan0 := NumGet(bd, 16, "Ptr")
        
        ; Process each pixel
        Loop h {
            y := A_Index - 1
            row := scan0 + y * stride
            Loop w {
                x := A_Index - 1
                p := row + x * 4
                b := NumGet(p, 0, "UChar")
                g := NumGet(p, 1, "UChar")
                r := NumGet(p, 2, "UChar")
                ; Calculate luminance
                lum := (r * 299 + g * 587 + b * 114) // 1000
                ; Apply threshold
                v := (lum >= threshold) ? 255 : 0
                NumPut("UChar", v, p, 0)
                NumPut("UChar", v, p, 1)
                NumPut("UChar", v, p, 2)
                NumPut("UChar", 255, p, 3)
            }
        }
        
        DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", bd)
    }
    
    ; Get PNG codec CLSID for saving
    static GetPngCLSID() {
        guid := Buffer(16, 0)
        NumPut("UInt", 0x557CF406, guid, 0)
        NumPut("UShort", 0x1A04, guid, 4)
        NumPut("UShort", 0x11D3, guid, 6)
        NumPut("UChar", 0x9A, guid, 8)
        NumPut("UChar", 0x73, guid, 9)
        NumPut("UChar", 0x00, guid, 10)
        NumPut("UChar", 0x00, guid, 11)
        NumPut("UChar", 0xF8, guid, 12)
        NumPut("UChar", 0x1E, guid, 13)
        NumPut("UChar", 0xF3, guid, 14)
        NumPut("UChar", 0x2E, guid, 15)
        return guid
    }
    
    ; Clean up old screenshot files
    static CleanOldFiles(maxFiles := Constants.SCREENSHOT_MAX_FILES, maxHours := Constants.SCREENSHOT_CLEANUP_HOURS) {
        try {
            ; Collect all screenshot files with metadata
            files := []  ; Array to store screenshot file information
            dir := A_Temp  ; Temporary directory path
            ; Collect all refine screenshot files in temp directory
            Loop Files dir "\refine_shot_*.png" {
                files.Push({
                    path: A_LoopFileFullPath, 
                    time: A_LoopFileTimeModified,
                    size: A_LoopFileSize
                })
            }
            
            ; Files are processed in order found (no sorting applied)
            
            ; Delete old files based on age and count limits
            if (files.Length > 0) {
                deleteCount := 0
                Loop files.Length {
                    i := A_Index
                    
                    ; Safety checks for array bounds and object validity
                    if (i > files.Length) 
                        break
                    
                    fileInfo := files[i]
                    if (!IsObject(fileInfo) || !fileInfo.HasOwnProp("path") || !fileInfo.HasOwnProp("time"))
                        continue
                        
                    filePath := fileInfo.path
                    if (filePath = "" || !FileExist(filePath))
                        continue
                    
                    hoursOld := DateDiff(A_Now, fileInfo.time, "Hours")
                    
                    ; Delete if too old or beyond file limit
                    if (i > maxFiles || hoursOld > maxHours) {
                        ; Check file accessibility before deletion
                        try {
                            ; Verify file is accessible
                            FileGetAttrib(filePath)
                            
                            ; Delete the file
                            FileDelete filePath
                            deleteCount++
                        } catch Error as e {
                            ; Continue to next file if deletion fails
                            continue
                        }
                    }
                }
            }
            
        } catch Error as e {
            ; Ignore cleanup errors silently
        }
    }
}

; ================================================================================
; USER INTERFACE MANAGER
; ================================================================================

class UIManager {
    static messagesSetup := false
    
    ; Initialize the UI system
    static Initialize() {
        if UI.gui && IsObject(UI.gui)
            return
        
        ConfigManager.Load()
        UIManager.CreateGUI()
        UIManager.SetupEventHandlers()
        UIManager.UpdateVisuals()
        SetTimer(() => UIManager.Update(), Config.UI_UPDATE_INTERVAL)
        
        ; Set up periodic config auto-save (every 10 seconds)
        SetTimer(() => ConfigManager.Save(), 10000)
    }
    
    ; Create the main GUI window
    static CreateGUI() {
        ; Create main window with white border
        UI.gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Border")
        UI.gui.MarginX := 0
        UI.gui.MarginY := 0
        UI.gui.BackColor := "000000"  ; Black background
        UI.gui.SetFont("s10 cFFFFFF", "Cascadia Mono")  ; White text by default
        
        ; Layout configuration
        pad := UI.pad
        gap := UI.gap
        btnH := UI.btnH
        hdrH := UI.hdrH
        
        ; Initialize section contents map for hierarchical structure
        UI.sectionContents["refining.macros"] := []
        UI.sectionContents["refining.statistics"] := []
        UI.sectionContents["refining.parameters.gamestate"] := []
        UI.sectionContents["refining.parameters.finesettings"] := []
        UI.sectionContents["refining.parameters.unlockables"] := []
        UI.sectionContents["refining.parameters.variables"] := []
        UI.sectionContents["unity.macros"] := []
        UI.sectionContents["unity.parameters.zodiac"] := []
        UI.sectionContents["unity.parameters.timewarp"] := []
        UI.sectionContents["other.macros"] := []
        UI.sectionContents["other.parameters"] := []
        UI.sectionContents["other.coordinates"] := []
        UI.sectionContents["other.info"] := []
        
        ; Legacy section contents (for migration compatibility)
        UI.sectionContents["macro"] := []
        UI.sectionContents["gamestate"] := []
        UI.sectionContents["finesettings"] := []
        UI.sectionContents["unlockables"] := []
        UI.sectionContents["variables"] := []
        UI.sectionContents["unityparameters"] := []
        UI.sectionContents["statistics"] := []
        UI.sectionContents["info"] := []
        
        ; Window width configuration
        UI.hudW := 580  ; Optimal width for all sections
        
        y := 0
        
        ; HEADER - white background
        UI.header := UI.gui.AddText(Format("x0 y0 w{} h{} +BackgroundFFFFFF", UI.hudW, hdrH), "")
        
        ; Title (center) - BLACK text on white background
        titleW := UI.hudW - 110  ; Title text width
        titleX := 55
        titleY := (hdrH - 26) // 2
        UI.titleText := UI.gui.AddText(Format("x{} y{} w{} h26 Center +BackgroundFFFFFF", 
                                       titleX, titleY, titleW), "Revolution Idle Helper v1.2")
        UI.titleText.SetFont("Bold s11 c000000", "Cascadia Mono")
        
        ; Eye icon (left) - BLACK on white background
        iconY := (hdrH - 24) // 2
        UI.btnEye := UI.gui.AddText(Format("x12 y{} w26 h24 Center +BackgroundFFFFFF", iconY), "👁")
        UI.btnEye.SetFont("s9 c000000", "Segoe UI Emoji")
        
        ; Close icon (right) - BLACK on white background (raised slightly)
        UI.btnClose := UI.gui.AddText(Format("x{} y{} w30 h24 Center +BackgroundFFFFFF", 
                                      UI.hudW - 42, iconY - 1), "✖")
        UI.btnClose.SetFont("Bold s11 c000000", "Segoe UI Symbol")
        
        ; Animated texts for when macro is running (hidden by default)
        UI.headerLeft := UI.gui.AddText(Format("x16 y{} w220 h26 Left +BackgroundFFFFFF +Hidden", 
                                        (hdrH - 26) // 2), "")
        UI.headerRight := UI.gui.AddText(Format("x{} y{} w160 h26 Right +BackgroundFFFFFF +Hidden", 
                                         UI.hudW - 176, (hdrH - 26) // 2), "")
        UI.headerLeft.SetFont("s10 c000000", "Cascadia Mono")
        UI.headerRight.SetFont("s10 c000000", "Cascadia Mono")
        
        ; Start/Stop button
        y := hdrH + pad
        btnStartW := 220  ; Start/stop button width
        btnX := (UI.hudW - btnStartW) // 2
        btn := UIManager.CreateStyledButton(btnX, y, btnStartW, btnH, "F5: Start macro", false)
        UI.btnStartStop := btn
        
        y += btnH + pad
        
        ; ═══════════════════════════════════════════════════════════
        ; HIERARCHICAL SECTIONS - UI ORGANIZATION
        ; ═══════════════════════════════════════════════════════════
        
        ; ═══ SECTION 1: MINERALS & REFINING HELPER ═══
        sectionH := UIManager.CreateBigSectionHeader("refining", y, UI.hudW, "MINERALS && REFINING HELPER")
        y += sectionH + UI.rowGap
        
        if State.sectionStates["refining"] {
            ; • MACROS SUBSECTION
            UIManager.CreateSubSectionHeader("refining.macros", y, UI.hudW, "Macro Selection", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["refining.macros"] {
                ; Refining macro buttons
                btnW := Constants.UI_BTN_TINY  ; Short text macro buttons
                totalW := (btnW * 3) + (gap * 2)
                x := (UI.hudW - totalW) // 2  ; Center without indentation
                
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Standard", false)
                UI.btnMacroStandard := btn
                UI.sectionContents["refining.macros"].Push(btn)
                
                x += btnW + gap
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Quick", false)
                UI.btnMacroQuick := btn
                UI.sectionContents["refining.macros"].Push(btn)
                
                x += btnW + gap
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Long", false)
                UI.btnMacroLong := btn
                UI.sectionContents["refining.macros"].Push(btn)
                
                y += btnH + UI.rowGap
                
                ; Endgame Exploit (centered in subsection)
                btnW := Constants.UI_BTN_XLARGE  
                x := (UI.hudW - btnW) // 2  ; Center without indentation
                
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Endgame Exploit", false)
                UI.btnMacroEndgame := btn
                UI.sectionContents["refining.macros"].Push(btn)
                
                y += btnH + UI.sectionGap
            }
            
            ; ┌─ STATISTICS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("refining.statistics", y, UI.hudW, "Game Statistics", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["refining.statistics"] {
                ; Preview image for screenshots (indented)
                previewW := UI.hudW - 2*pad - 24  ; Account for indentation
                rect := State.captureRect
                previewH := Max(20, Round(previewW * rect.h / Max(rect.w, 1)))
                pic := UI.gui.AddPicture(Format("x{} y{} w{} h{} +Border", pad + 12, y, previewW, previewH), "")
                UI.imgPreview := pic
                UI.sectionContents["refining.statistics"].Push(pic)
                
                y += previewH + gap
                
                ; Cycle count display (indented)
                lbl := UI.gui.AddText(Format("x{} y{} w{} h35", pad + 12, y, previewW), "Cycles: 0")
                lbl.SetFont("s10", "Cascadia Mono")
                UI.lblStatistics := lbl
                UI.sectionContents["refining.statistics"].Push(lbl)
                
                y += 35 + 5  ; Minimal spacing between related statistics labels
                
                ; Average cycle time display (indented)
                lbl := UI.gui.AddText(Format("x{} y{} w{} h35", pad + 12, y, previewW), 
                                             "Avg cycle: --:--:--:-")
                lbl.SetFont("s10", "Cascadia Mono")
                UI.lblCycleTime := lbl
                UI.sectionContents["refining.statistics"].Push(lbl)
                
                y += 35 + UI.sectionGap  ; Account for full label height plus section spacing
            }
            
            ; ┌─ PARAMETERS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("refining.parameters", y, UI.hudW, "Parameters", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["refining.parameters"] {
                ; Game State selection
                UIManager.CreateSubSectionHeader("refining.parameters.gamestate", y, UI.hudW, "Game State", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["refining.parameters.gamestate"] {
                    ; Game state buttons (indented more)
                    btnW := Constants.UI_BTN_SMALL  ; Game state button width
                    totalW := (btnW * 4) + (gap * 3)
                    x := (UI.hudW - totalW) // 2  ; Center without indentation
                    
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Early", false)
                    UI.btnStateEarly := btn
                    UI.sectionContents["refining.parameters.gamestate"].Push(btn)
                    
                    x += btnW + gap
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Mid", false)
                    UI.btnStateMid := btn
                    UI.sectionContents["refining.parameters.gamestate"].Push(btn)
                    
                    x += btnW + gap
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Late", false)
                    UI.btnStateLate := btn
                    UI.sectionContents["refining.parameters.gamestate"].Push(btn)
                    
                    x += btnW + gap
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Custom", false)
                    UI.btnStateCustom := btn
                    UI.sectionContents["refining.parameters.gamestate"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Custom spawn input (centered with indentation)
                    lblW := 170  ; Custom input label width
                    edtW := 50   ; Width for 2-3 characters
                    customGap := 20  ; Custom gap between label and textbox
                    totalW := lblW + edtW + Constants.UI_INPUT_GAP
                    x := (UI.hudW - totalW) // 2 + 12  ; Slight indent for nested elements
                    
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Spawn reps:")
                    UI.sectionContents["refining.parameters.gamestate"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.customSpawnReps)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputCustomSpawn := edt
                    UI.sectionContents["refining.parameters.gamestate"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Custom polish input (centered with indentation)
                    x := (UI.hudW - totalW) // 2 + 12  ; Slight indent for nested elements
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Polish reps:")
                    UI.sectionContents["refining.parameters.gamestate"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.customPolishReps)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputCustomPolish := edt
                    UI.sectionContents["refining.parameters.gamestate"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.sectionGap
                }
                
                ; Fine Settings
                UIManager.CreateSubSectionHeader("refining.parameters.finesettings", y, UI.hudW, "Fine Settings", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["refining.parameters.finesettings"] {
                    ; Fine Settings buttons (double indented)
                    btnW := Constants.UI_BTN_XLARGE  ; Fine settings button width
                    totalW := (btnW * 2) + gap
                    x := (UI.hudW - totalW) // 2  ; Center without indentation
                    
                    ; Row 1: Auto Refining, Auto RfT Upgrade
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.autoRefining ? "Auto Refining" : "No Refining", State.autoRefining)
                    UI.btnToggleRefining := btn
                    UI.sectionContents["refining.parameters.finesettings"].Push(btn)
                    
                    x += btnW + gap
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.autoRftUpgrade ? "Auto RfT Upg" : "No RfT Upg", State.autoRftUpgrade)
                    UI.btnToggleRftUpgrade := btn
                    UI.sectionContents["refining.parameters.finesettings"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Row 2: Weapon Polish Mode
                    btnW := Constants.UI_BTN_FULL - 48  ; Adjust for double indentation
                    x := (UI.hudW - btnW) // 2 + 12  ; Slight indent for nested elements
                    
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.allWeaponsPolish ? "All Weapons Polish" : "Sword Polish Only", State.allWeaponsPolish)
                    UI.btnTogglePolishMode := btn
                    UI.sectionContents["refining.parameters.finesettings"].Push(btn)
                    
                    y += btnH + UI.sectionGap
                }
                
                ; Automation Unlockables
                UIManager.CreateSubSectionHeader("refining.parameters.unlockables", y, UI.hudW, "Automation Unlockables", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["refining.parameters.unlockables"] {
                    ; Each button on its own line for full width
                    btnW := Constants.UI_BTN_UNLOCKS - 24  ; Adjust for slight indentation
                    x := (UI.hudW - btnW) // 2  ; Center without indentation
                    
                    ; Row 1: Autospawn
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.autospawnUnlocked ? "Autospawn UNLOCKED" : "Autospawn LOCKED", State.autospawnUnlocked)
                    UI.btnToggleAutospawn := btn
                    UI.sectionContents["refining.parameters.unlockables"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Row 2: Automerge
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.automergeUnlocked ? "Automerge UNLOCKED" : "Automerge LOCKED", State.automergeUnlocked)
                    UI.btnToggleAutomerge := btn
                    UI.sectionContents["refining.parameters.unlockables"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Row 3: Auto Max Level
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.autoMaxLevelUnlocked ? "Auto Max Lvl UNLOCKED" : "Auto Max Lvl LOCKED", State.autoMaxLevelUnlocked)
                    UI.btnToggleAutoMaxLevel := btn
                    UI.sectionContents["refining.parameters.unlockables"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Row 4: Auto Weapon Polish
                    btn := UIManager.CreateStyledButton(x, y, btnW, btnH, 
                        State.autoWeaponPolishUnlocked ? "Auto Wpn Polish UNLOCKED" : "Auto Wpn Polish LOCKED", State.autoWeaponPolishUnlocked)
                    UI.btnToggleAutoWeaponPolish := btn
                    UI.sectionContents["refining.parameters.unlockables"].Push(btn)
                    
                    y += btnH + UI.sectionGap
                }
                
                ; Variables
                UIManager.CreateSubSectionHeader("refining.parameters.variables", y, UI.hudW, "Variables", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["refining.parameters.variables"] {
                    ; Centered variable inputs with full labels
                    lblW := 340  ; Variables label width (no indentation needed)
                    edtW := 80   ; Width for 5 characters
                    customGap := 20  ; Custom gap between label and textbox
                    totalW := lblW + edtW + Constants.UI_INPUT_GAP
                    x := (UI.hudW - totalW) // 2  ; Center without indentation
                    
                    ; Highest mineral level input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Highest mineral level:")
                    UI.lblMineralLevel := lbl
                    UI.sectionContents["refining.parameters.variables"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.mineralLevel)
                    edt.SetFont("s11 c000000", "Cascadia Mono")
                    UI.inputMineralLevel := edt
                    UI.sectionContents["refining.parameters.variables"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Merge wait time input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Merge wait time (ms):")
                    UI.lblMergeWait := lbl
                    UI.sectionContents["refining.parameters.variables"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.mergeWaitTime)
                    edt.SetFont("s11 c000000", "Cascadia Mono")
                    UI.inputMergeWait := edt
                    UI.sectionContents["refining.parameters.variables"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Exploit wait time input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Exploit wait time (ms):")
                    UI.lblExploitWait := lbl
                    UI.sectionContents["refining.parameters.variables"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.exploitWaitTime)
                    edt.SetFont("s11 c000000", "Cascadia Mono")
                    UI.inputExploitWait := edt
                    UI.sectionContents["refining.parameters.variables"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    y += UI.rowGap  ; Reduced spacing between subsections
                }
            }
        }
        
        ; Close refining section border  
        y += UIManager.CloseSectionBorder("refining")
        
        ; ═══ SECTION 2: UNITY HELPER ═══
        sectionH := UIManager.CreateBigSectionHeader("unity", y, UI.hudW, "UNITY HELPER")
        y += sectionH + UI.rowGap
        
        if State.sectionStates["unity"] {
            ; ┌─ MACROS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("unity.macros", y, UI.hudW, "Macro Selection", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["unity.macros"] {
                ; Auto Unity button (first, centered)
                btnW := Constants.UI_BTN_LARGE
                x := (UI.hudW - btnW) // 2  ; Center without indentation
                
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Auto Unity", false)
                UI.btnMacroAutoUnity := btn
                UI.sectionContents["unity.macros"].Push(btn)
                
                y += btnH + UI.rowGap
                
                ; Zodiac Redistribution (second line, full width)
                btnW := Constants.UI_BTN_FULL + 50  ; Use extra wide button for long text
                x := (UI.hudW - btnW) // 2  ; Center without indentation to maximize width
                
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Zodiac Redistribution", false)
                UI.btnMacroZodiacRedistribution := btn
                UI.sectionContents["unity.macros"].Push(btn)
                
                y += btnH + UI.sectionGap
            }
            
            ; ┌─ PARAMETERS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("unity.parameters", y, UI.hudW, "Parameters", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["unity.parameters"] {
                ; Zodiac Selection
                UIManager.CreateSubSectionHeader("unity.parameters.zodiac", y, UI.hudW, "Zodiac Selection", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["unity.parameters.zodiac"] {
                    ; Section label
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h35 Center", pad, y, UI.hudW - 2*pad), "Select Zodiac Element:")
                    lbl.SetFont("s11 cFFFFFF", "Cascadia Mono")
                    UI.sectionContents["unity.parameters.zodiac"].Push(lbl)
                    
                    y += 35 + UI.rowGap  ; Account for full label height plus spacing
                    
                    ; Zodiac buttons in a 2x2 grid
                    btnW := Constants.UI_BTN_LARGE
                    btnH := UI.btnH
                    zodiacGap := UI.gap
                    startX := (UI.hudW - (2 * btnW + zodiacGap)) // 2  ; Center the button grid
                    
                    ; Earth Zodiac
                    btn := UIManager.CreateStyledButton(startX, y, btnW, btnH, "Earth Zodiac", State.zodiacEarth)
                    UI.btnZodiacEarth := btn
                    UI.sectionContents["unity.parameters.zodiac"].Push(btn)
                    
                    ; Fire Zodiac  
                    btn := UIManager.CreateStyledButton(startX + btnW + zodiacGap, y, btnW, btnH, "Fire Zodiac", State.zodiacFire)
                    UI.btnZodiacFire := btn
                    UI.sectionContents["unity.parameters.zodiac"].Push(btn)
                    
                    y += btnH + UI.rowGap
                    
                    ; Wind Zodiac
                    btn := UIManager.CreateStyledButton(startX, y, btnW, btnH, "Wind Zodiac", State.zodiacWind)
                    UI.btnZodiacWind := btn
                    UI.sectionContents["unity.parameters.zodiac"].Push(btn)
                    
                    ; Water Zodiac
                    btn := UIManager.CreateStyledButton(startX + btnW + zodiacGap, y, btnW, btnH, "Water Zodiac", State.zodiacWater)
                    UI.btnZodiacWater := btn
                    UI.sectionContents["unity.parameters.zodiac"].Push(btn)
                    
                    y += btnH + UI.sectionGap
                }
                
                ; Time Warp Settings
                UIManager.CreateSubSectionHeader("unity.parameters.timewarp", y, UI.hudW, "Variables", 48)
                y += 28 + UI.rowGap
                
                if State.sectionStates["unity.parameters.timewarp"] {
                    ; Configure label and input dimensions
                    lblW := 360  ; Label width for complete text display
                    edtW := 80
                    customGap := 20  ; Custom gap between label and textbox
                    totalW := lblW + edtW + Constants.UI_INPUT_GAP
                    x := (UI.hudW - totalW) // 2  ; Center the input group
                    
                    ; Time warp wait time input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Time warp wait time (ms):")
                    lbl.SetFont("s10 cFFFFFF", "Cascadia Mono")
                    UI.lblTimeWarpWaitTime := lbl
                    UI.sectionContents["unity.parameters.timewarp"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.timeWarpWaitTime)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputTimeWarpWaitTime := edt
                    UI.sectionContents["unity.parameters.timewarp"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Time warp reps input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Time warp reps:")
                    lbl.SetFont("s10 cFFFFFF", "Cascadia Mono")
                    UI.lblTimeWarpReps := lbl
                    UI.sectionContents["unity.parameters.timewarp"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.timeWarpReps)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputTimeWarpReps := edt
                    UI.sectionContents["unity.parameters.timewarp"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Auto Unity max reps input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Auto Unity reps:")
                    lbl.SetFont("s10 cFFFFFF", "Cascadia Mono")
                    UI.lblAutoUnityMaxReps := lbl
                    UI.sectionContents["unity.parameters.timewarp"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.autoUnityMaxReps)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputAutoUnityMaxReps := edt
                    UI.sectionContents["unity.parameters.timewarp"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                    
                    ; Zodiac redistribution wait time input
                    lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y + Constants.UI_LABEL_OFFSET, lblW), "Redistribution wait time (ms):")
                    lbl.SetFont("s10 cFFFFFF", "Cascadia Mono")
                    UI.lblZodiacRedistributionWait := lbl
                    UI.sectionContents["unity.parameters.timewarp"].Push(lbl)
                    
                    edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.zodiacRedistributionWait)
                    edt.SetFont("s10 c000000", "Cascadia Mono")
                    UI.inputZodiacRedistributionWait := edt
                    UI.sectionContents["unity.parameters.timewarp"].Push(edt)
                    
                    y += Constants.UI_INPUT_HEIGHT + UI.sectionGap
                }
            }
        }
        
        ; Close unity section border
        y += UIManager.CloseSectionBorder("unity")
        
        ; ═══ SECTION 3: OTHER TOOLS ═══
        sectionH := UIManager.CreateBigSectionHeader("other", y, UI.hudW, "OTHER TOOLS")
        y += sectionH + UI.rowGap
        
        if State.sectionStates["other"] {
            ; ┌─ MACROS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("other.macros", y, UI.hudW, "Macro Selection", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["other.macros"] {
                ; Autoclicker (first, centered)
                btnW := Constants.UI_BTN_XLARGE  
                x := (UI.hudW - btnW) // 2  ; Center without indentation
                
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Autoclicker", false)
                UI.btnMacroAutoClicker := btn
                UI.sectionContents["other.macros"].Push(btn)
                
                y += btnH + UI.rowGap
                
                ; Time macros on second line
                btnW := Constants.UI_BTN_LARGE  ; Base button width
                totalW := (btnW + 20) + btnW + gap  ; Time Warp Burst is wider
                x := (UI.hudW - totalW) // 2  ; Center without indentation
                
                btn := UIManager.CreateStyledButton(x, y, btnW + 20, btnH, "Time Warp Burst", false)
                UI.btnMacroTimeWarp := btn
                UI.sectionContents["other.macros"].Push(btn)
                
                x += (btnW + 20) + gap  ; Account for wider Time Warp button
                btn := UIManager.CreateStyledButton(x, y, btnW, btnH, "Time Flux Buy", false)
                UI.btnMacroTimeFluxBuy := btn
                UI.sectionContents["other.macros"].Push(btn)
                
                y += btnH + UI.sectionGap
            }
            
            ; ┌─ PARAMETERS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("other.parameters", y, UI.hudW, "Parameters", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["other.parameters"] {
                ; Time warp interval input (first)
                lblW := 400  ; Reduced label space to 400px
                edtW := 80   ; Textbox width (back to original)
                customGap := 20   ; Minimal gap to eliminate empty space
                totalW := lblW + edtW + customGap
                x := (UI.hudW - totalW) // 2  ; Center without indentation
                
                lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Time Warp // Burst Interval (ms):")
                UI.lblTimewarp := lbl
                UI.sectionContents["other.parameters"].Push(lbl)
                
                edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.timewarpInterval)
                edt.SetFont("s11 c000000", "Cascadia Mono")
                UI.inputTimewarp := edt
                UI.sectionContents["other.parameters"].Push(edt)
                
                y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                
                ; Time warp minutes to spend input
                lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Time Warp // Minutes to spend:")
                UI.lblTimeWarpMinutesToSpend := lbl
                UI.sectionContents["other.parameters"].Push(lbl)
                
                edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.timeWarpMinutesToSpend)
                edt.SetFont("s11 c000000", "Cascadia Mono")
                UI.inputTimeWarpMinutesToSpend := edt
                UI.sectionContents["other.parameters"].Push(edt)
                
                y += Constants.UI_INPUT_HEIGHT + UI.rowGap
                
                ; Delay between actions input
                lbl := UI.gui.AddText(Format("x{} y{} w{} h30", x, y+4, lblW), "Delay between actions (ms):")
                UI.lblMicroDelay := lbl
                UI.sectionContents["other.parameters"].Push(lbl)
                
                edt := UI.gui.AddEdit(Format("x{} y{} w{} h30 Center +Border", x + lblW + customGap, y, edtW), State.microDelayMs)
                edt.SetFont("s11 c000000", "Cascadia Mono")
                UI.inputMicroDelay := edt
                UI.sectionContents["other.parameters"].Push(edt)
                
                y += Constants.UI_INPUT_HEIGHT + UI.sectionGap
            }
            
            ; ┌─ COORDINATE SETTINGS SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("other.coordinates", y, UI.hudW, "Coordinate Settings", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["other.coordinates"] {
                ; Coordinate picker instructions
                instrText := "Double-click a coordinate to set it. Click anywhere on screen when prompted."
                lbl := UI.gui.AddText(Format("x{} y{} w{} h30", pad + 12, y, UI.hudW - 2*pad - 24), instrText)
                lbl.SetFont("s9", "Cascadia Mono")
                UI.sectionContents["other.coordinates"].Push(lbl)
                y += 35 + UI.rowGap
                
                ; Create a scrollable ListView for coordinates
                listW := UI.hudW - 2*pad - 24
                listH := 300  ; Fixed height with automatic scrolling
                x := pad + 12
                
                ; Create ListView with columns - keep it simple
                lvCoords := UI.gui.AddListView(Format("x{} y{} w{} h{} -Multi Grid Lines", x, y, listW, listH), ["Coordinate", "X", "Y", "Description"])
                lvCoords.SetFont("s9", "Cascadia Mono")  ; Same font as HUD
                
                ; Set basic colors - black background, white text
                try {
                    DllCall("SendMessage", "Ptr", lvCoords.Hwnd, "UInt", 0x1024, "Ptr", 0, "Ptr", 0xFFFFFF)  ; LVM_SETTEXTCOLOR - white text
                    DllCall("SendMessage", "Ptr", lvCoords.Hwnd, "UInt", 0x1025, "Ptr", 0, "Ptr", 0x000000)  ; LVM_SETTEXTBKCOLOR - black background
                    DllCall("SendMessage", "Ptr", lvCoords.Hwnd, "UInt", 0x1026, "Ptr", 0, "Ptr", 0x000000)  ; LVM_SETBKCOLOR - black background
                    
                    ; Apply dark theme to scrollbars only (most reliable)
                    DllCall("UxTheme.dll\SetWindowTheme", "Ptr", lvCoords.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
                }
                UI.sectionContents["other.coordinates"].Push(lvCoords)
                
                ; Set column widths
                lvCoords.ModifyCol(1, 120)  ; Coordinate name
                lvCoords.ModifyCol(2, 60)   ; X value
                lvCoords.ModifyCol(3, 60)   ; Y value  
                lvCoords.ModifyCol(4, listW - 240)  ; Description
                
                ; Populate ListView with all coordinates
                coordDescriptions := Map(
                    "spawn", "Mineral spawn button",
                    "spawnLevel", "Spawn level input",
                    "maxLevel", "Max level button",
                    "autospawn", "Autospawn toggle",
                    "polishOpen", "Open polish menu",
                    "polishPrestige", "Polish prestige button",
                    "polishPrestigeConfirm", "Confirm polish prestige",
                    "polishLevelUp", "Polish level up",
                    "polishClose", "Close polish menu",
                    "sword", "Sword weapon",
                    "axe", "Axe weapon",
                    "spear", "Spear weapon", 
                    "bow", "Bow weapon",
                    "knuckle", "Knuckle weapon",
                    "refineOpen", "Open refine menu",
                    "refinePrestige", "Refine prestige button",
                    "refinePrestigeConfirm", "Confirm refine prestige",
                    "refineClose", "Close refine menu",
                    "timeFluxTab", "Time flux tab",
                    "attacksTab", "Attacks tab",
                    "shopTab", "Shop tab",
                    "automationTab", "Automation tab",
                    "unityTab", "Unity tab",
                    "automerge", "Automerge toggle",
                    "timewarpStart", "Start time warp",
                    "timewarpStop", "Stop time warp",
                    "timeWarpMinutesSpend", "Time warp minutes to spend",
                    "buyTimeFlux", "Buy time flux",
                    "purchaseConfirm", "Confirm purchase",
                    "unite", "Unite button",
                    "uniteConfirm1", "Unite confirmation 1",
                    "uniteConfirm2", "Unite confirmation 2",
                    "zodiacWater", "Water zodiac element",
                    "zodiacWind", "Wind zodiac element",
                    "zodiacEarth", "Earth zodiac element",
                    "zodiacFire", "Fire zodiac element",
                    "redistributionTopBox", "Redistribution top box",
                    "redistributionBottomBox", "Redistribution bottom box",
                    "redistribute", "Redistribute button",
                    "emptySpace", "Empty space for exploit"
                )
                
                ; Add coordinates to ListView organized by category
                coordCategories := [
                    ; Mineral Management
                    ["spawn", "spawnLevel", "maxLevel", "autospawn"],
                    
                    ; Weapon Selection
                    ["sword", "axe", "spear", "bow", "knuckle"],
                    
                    ; Polish Menu
                    ["polishOpen", "polishPrestige", "polishPrestigeConfirm", "polishLevelUp", "polishClose"],
                    
                    ; Refining Menu  
                    ["refineOpen", "refinePrestige", "refinePrestigeConfirm", "refineClose"],
                    
                    ; Unity System
                    ["unite", "uniteConfirm1", "uniteConfirm2"],
                    
                    ; Zodiac Elements
                    ["zodiacWater", "zodiacWind", "zodiacEarth", "zodiacFire"],
                    
                    ; Zodiac Redistribution
                    ["redistributionTopBox", "redistributionBottomBox", "redistribute"],
                    
                    ; Game Tabs
                    ["timeFluxTab", "attacksTab", "shopTab", "automationTab", "unityTab"],
                    
                    ; Time Control
                    ["timewarpStart", "timewarpStop"],
                    
                    ; Shop Actions
                    ["buyTimeFlux", "purchaseConfirm"],
                    
                    ; Automation
                    ["automerge"],
                    
                    ; Special Actions
                    ["emptySpace"]
                ]
                
                ; Add coordinates in category order
                for category in coordCategories {
                    for coordName in category {
                        if State.coords.Has(coordName) {
                            coords := State.coords[coordName]
                            desc := coordDescriptions.Has(coordName) ? coordDescriptions[coordName] : "Game coordinate"
                            lvCoords.Add(, coordName, coords[1], coords[2], desc)
                        }
                    }
                }
                
                ; Handle double-click to start coordinate picking
                lvCoords.OnEvent("DoubleClick", (*) => CoordinatePicker.HandleListViewDoubleClick(lvCoords))
                
                ; Store ListView reference for updates
                UI.coordListView := lvCoords
                
                y += listH + UI.sectionGap
            }
            
            ; ┌─ INFO SUBSECTION ─┐
            UIManager.CreateSubSectionHeader("other.info", y, UI.hudW, "Information && Hotkeys", 24)
            y += 28 + UI.rowGap
            
            if State.sectionStates["other.info"] {
                ; Hotkey information text (indented)
                infoText := "F5: Start/Stop`n"
                          . "F10: Compact Mode`n"
                          . "Esc: Exit"
                
                lbl := UI.gui.AddText(Format("x{} y{} w{} h200", pad + 12, y, UI.hudW - 2*pad - 24), infoText)
                lbl.SetFont("s10", "Cascadia Mono")
                UI.lblInfo := lbl
                UI.sectionContents["other.info"].Push(lbl)
                
                y += 200 + UI.gap
                
                ; Credit line - right aligned (indented)
                creditLbl := UI.gui.AddText(Format("x{} y{} w{} h35 Right", pad + 12, y, UI.hudW - 2*pad - 24), "Script by GullibleMonkey")
                creditLbl.SetFont("s10", "Cascadia Mono")
                UI.sectionContents["other.info"].Push(creditLbl)
                
                y += UI.sectionGap
            }
            
            y += UI.sectionGap  ; Space after info subsection
        }
        
        ; Close other section border
        y += UIManager.CloseSectionBorder("other")
        
        ; Show window at saved position with total height
        totalH := y + 10  ; Minimal bottom margin
        ini := Config.CONFIG_FILE
        hx := IniRead(ini, "UI", "X", 12)
        hy := IniRead(ini, "UI", "Y", 51)
        UI.gui.Show(Format("x{} y{} w{} h{} NoActivate", hx, hy, UI.hudW, totalH))
    }
    
    ; Create a styled button
    static CreateStyledButton(x, y, w, h, text, isActive) {
        ; Create text control styled as button
        btn := UI.gui.AddText(Format("x{} y{} w{} h{} Center +Border", x, y, w, h), text)
        
        ; Store button state
        UI.buttonStates[btn.Hwnd] := isActive
        
        ; Apply appropriate colors
        UIManager.UpdateButtonStyle(btn, isActive)
        
        return btn
    }
    
    ; Create a collapsible section header with decorative lines
    static CreateSectionHeader(section, y, hudW, title) {
        ; Add arrow indicator based on state
        arrow := State.sectionStates[section] ? "▼" : "►"
        fullTitle := "--- " arrow " " title " ---"
        
        ; Create clickable header
        header := UI.gui.AddText(Format("x16 y{} w{} h30 Center", y, hudW - 32), fullTitle)
        header.SetFont("s10 cFFFFFF", "Cascadia Mono")
        UI.sectionHeaders[section] := header
    }
    
    ; Create a clean big section header with visual separation
    static CreateBigSectionHeader(section, y, hudW, title) {
        ; Check if section exists in state, initialize if not
        if !State.sectionStates.Has(section)
            State.sectionStates[section] := true
            
        ; Add arrow indicator based on state
        arrow := State.sectionStates[section] ? "▼" : "►"
        
        ; Create the main section header with color coding  
        fullTitle := arrow . " " . title
        header := UI.gui.AddText(Format("x8 y{} w{} h30 Center", y, hudW - 16), fullTitle)
        
        ; Color code by section
        if (section = "refining") {
            header.SetFont("s12 Bold cFF4444", "Cascadia Mono")  ; Red for Minerals
        } else if (section = "unity") {
            header.SetFont("s12 Bold c4444FF", "Cascadia Mono")  ; Blue for Unity  
        } else if (section = "other") {
            header.SetFont("s12 Bold c44FF44", "Cascadia Mono")  ; Green for Other Tools
        } else {
            header.SetFont("s12 Bold cFFFFFF", "Cascadia Mono")  ; Default white
        }
        UI.sectionHeaders[section] := header
        
        return 30  ; Return height for spacing calculations
    }
    
    ; Create a clean sub-section header with visual hierarchy
    static CreateSubSectionHeader(section, y, hudW, title, indent := 24) {
        ; Check if section exists in state, initialize if not
        if !State.sectionStates.Has(section)
            State.sectionStates[section] := true
            
        ; Add arrow indicator based on state  
        arrow := State.sectionStates[section] ? "▼" : "►"
        fullTitle := "• " . arrow . " " . title
        
        ; Create clickable header with proper indentation and color coding
        header := UI.gui.AddText(Format("x{} y{} w{} h28 Left", indent, y, hudW - indent - 8), fullTitle)
        
        ; Color code by parent section
        if (InStr(section, "refining")) {
            header.SetFont("s10 Bold cFFAAAA", "Cascadia Mono")  ; Light red for Minerals subsections
        } else if (InStr(section, "unity")) {
            header.SetFont("s10 Bold cAAAAFF", "Cascadia Mono")  ; Light blue for Unity subsections  
        } else if (InStr(section, "other")) {
            header.SetFont("s10 Bold cAAFFAA", "Cascadia Mono")  ; Light green for Other Tools subsections
        } else {
            header.SetFont("s10 Bold c00CCFF", "Cascadia Mono")  ; Default light blue
        }
        UI.sectionHeaders[section] := header
        return 28  ; Return height for spacing calculations
    }
    
    
    
    ; Add visual spacing for section completion
    static CloseSectionBorder(section) {
        ; Just return a small gap for section separation
        return State.sectionStates.Has(section) && State.sectionStates[section] ? 15 : 5
    }
    
    ; Create compact mode GUI (small window with eye icon)
    static CreateCompactGUI() {
        ; Create small window with white background (square matching header height)
        UI.compactGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale ")
        UI.compactGui.BackColor := "FFFFFF"  ; White background
        UI.compactGui.MarginX := 0
        UI.compactGui.MarginY := 0
        
        ; Add eye icon (black on white) - centered in square
        iconSize := UI.hdrH
        eyeY := (iconSize - 24) // 2  ; Center the icon vertically
        eye := UI.compactGui.AddText(Format("x0 y{} w{} h24 Center +BackgroundFFFFFF", eyeY, iconSize), "👁")
        eye.SetFont("s9 c000000", "Segoe UI Emoji")  ; Same size as header icon
        eye.OnEvent("Click", (*) => UIManager.ToggleCompact())
        
        ; Position near original window with fallback
        x := 100
        y := 100
        if UI.gui && IsObject(UI.gui) {
            try {
                WinGetPos &x, &y, , , "ahk_id " UI.gui.Hwnd
            } catch {
                x := 100
                y := 100
            }
        }
        UI.compactGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, iconSize, iconSize))
    }
    
    ; Toggle between normal and compact mode
    static ToggleCompact() {
        if UI.isCompact {
            ; Restore from compact mode
            x := 100
            y := 100
            if UI.compactGui && IsObject(UI.compactGui) {
                try {
                    WinGetPos &x, &y, , , "ahk_id " UI.compactGui.Hwnd
                } catch {
                    x := 100
                    y := 100
                }
                UI.compactGui.Destroy()
                UI.compactGui := 0
            }
            
            UI.isCompact := false
            UI.isVisible := true
            
            ; Show main GUI
            if UI.gui && IsObject(UI.gui) {
                UI.gui.Show("NoActivate")
                WinMove x, y, , , "ahk_id " UI.gui.Hwnd
            } else {
                UIManager.Initialize()
                if UI.gui && IsObject(UI.gui) {
                    WinMove x, y, , , "ahk_id " UI.gui.Hwnd
                }
            }
        } else {
            ; Enter compact mode
            x := 100
            y := 100
            if UI.gui && IsObject(UI.gui) {
                try {
                    WinGetPos &x, &y, , , "ahk_id " UI.gui.Hwnd
                } catch {
                    x := 100
                    y := 100
                }
                UI.gui.Hide()
            }
            
            UI.isCompact := true
            UI.isVisible := false
            UIManager.CreateCompactGUI()
            
            if UI.compactGui
                WinMove x, y, , , "ahk_id " UI.compactGui.Hwnd
        }
        
        Util.FocusGame()
    }
    
    ; Setup event handlers for all controls
    static SetupEventHandlers() {
        ; Setup drag handler once
        if !UIManager.messagesSetup {
            OnMessage(0x201, ObjBindMethod(UIManager, "OnDrag"))
            UIManager.messagesSetup := true
        }
        
        ; Header controls - always check if exists
        if UI.btnEye && IsObject(UI.btnEye)
            UI.btnEye.OnEvent("Click", (*) => UIManager.ToggleCompact())
        if UI.btnClose && IsObject(UI.btnClose)
            UI.btnClose.OnEvent("Click", (*) => ExitApp())
        
        ; Section headers (collapsible)
        for key, header in UI.sectionHeaders {
            localSection := key
            if header && IsObject(header) {
                header.OnEvent("Click", UIManager.ToggleSection.Bind(, localSection))
            }
        }
        
        ; Main button
        if UI.btnStartStop && IsObject(UI.btnStartStop)
            UI.btnStartStop.OnEvent("Click", (*) => Controller.ToggleStart())
        
        ; Macro selection buttons - check existence before adding handler
        if UI.btnMacroStandard && IsObject(UI.btnMacroStandard) {
            try UI.btnMacroStandard.OnEvent("Click", (*) => Controller.SelectMacro("standard"))
        }
        if UI.btnMacroQuick && IsObject(UI.btnMacroQuick) {
            try UI.btnMacroQuick.OnEvent("Click", (*) => Controller.SelectMacro("quick"))
        }
        if UI.btnMacroLong && IsObject(UI.btnMacroLong) {
            try UI.btnMacroLong.OnEvent("Click", (*) => Controller.SelectMacro("long"))
        }
        if UI.btnMacroEndgame && IsObject(UI.btnMacroEndgame) {
            try UI.btnMacroEndgame.OnEvent("Click", (*) => Controller.SelectMacro("endgame"))
        }
        if UI.btnMacroTimeWarp && IsObject(UI.btnMacroTimeWarp) {
            try UI.btnMacroTimeWarp.OnEvent("Click", (*) => Controller.SelectMacro("timewarp"))
        }
        if UI.btnMacroAutoClicker && IsObject(UI.btnMacroAutoClicker) {
            try UI.btnMacroAutoClicker.OnEvent("Click", (*) => Controller.SelectMacro("autoclicker"))
        }
        if UI.btnMacroTimeFluxBuy && IsObject(UI.btnMacroTimeFluxBuy) {
            try UI.btnMacroTimeFluxBuy.OnEvent("Click", (*) => Controller.SelectMacro("timefluxbuy"))
        }
        if UI.btnMacroAutoUnity && IsObject(UI.btnMacroAutoUnity) {
            try UI.btnMacroAutoUnity.OnEvent("Click", (*) => Controller.SelectMacro("autounity"))
        }
        if UI.btnMacroZodiacRedistribution && IsObject(UI.btnMacroZodiacRedistribution) {
            try UI.btnMacroZodiacRedistribution.OnEvent("Click", (*) => Controller.SelectMacro("zodiacredistribution"))
        }
        
        ; Game state buttons
        if UI.btnStateEarly && IsObject(UI.btnStateEarly) {
            try UI.btnStateEarly.OnEvent("Click", (*) => Controller.SelectGameState("early"))
        }
        if UI.btnStateMid && IsObject(UI.btnStateMid) {
            try UI.btnStateMid.OnEvent("Click", (*) => Controller.SelectGameState("mid"))
        }
        if UI.btnStateLate && IsObject(UI.btnStateLate) {
            try UI.btnStateLate.OnEvent("Click", (*) => Controller.SelectGameState("late"))
        }
        if UI.btnStateCustom && IsObject(UI.btnStateCustom) {
            try UI.btnStateCustom.OnEvent("Click", (*) => Controller.SelectGameState("custom"))
        }
        
        ; Fine Settings buttons
        if UI.btnToggleRefining && IsObject(UI.btnToggleRefining) {
            try UI.btnToggleRefining.OnEvent("Click", (*) => Controller.ToggleRefining())
        }
        if UI.btnToggleRftUpgrade && IsObject(UI.btnToggleRftUpgrade) {
            try UI.btnToggleRftUpgrade.OnEvent("Click", (*) => Controller.ToggleRftUpgrade())
        }
        if UI.btnTogglePolishMode && IsObject(UI.btnTogglePolishMode) {
            try UI.btnTogglePolishMode.OnEvent("Click", (*) => Controller.TogglePolishMode())
        }
        
        ; Automation Unlockables buttons
        if UI.btnToggleAutospawn && IsObject(UI.btnToggleAutospawn) {
            try UI.btnToggleAutospawn.OnEvent("Click", (*) => Controller.ToggleAutospawn())
        }
        if UI.btnToggleAutomerge && IsObject(UI.btnToggleAutomerge) {
            try UI.btnToggleAutomerge.OnEvent("Click", (*) => Controller.ToggleAutomerge())
        }
        if UI.btnToggleAutoMaxLevel && IsObject(UI.btnToggleAutoMaxLevel) {
            try UI.btnToggleAutoMaxLevel.OnEvent("Click", (*) => Controller.ToggleAutoMaxLevel())
        }
        if UI.btnToggleAutoWeaponPolish && IsObject(UI.btnToggleAutoWeaponPolish) {
            try UI.btnToggleAutoWeaponPolish.OnEvent("Click", (*) => Controller.ToggleAutoWeaponPolish())
        }
        
        ; Unity Parameters buttons
        if UI.btnZodiacEarth && IsObject(UI.btnZodiacEarth) {
            try UI.btnZodiacEarth.OnEvent("Click", (*) => Controller.ToggleZodiacEarth())
        }
        if UI.btnZodiacFire && IsObject(UI.btnZodiacFire) {
            try UI.btnZodiacFire.OnEvent("Click", (*) => Controller.ToggleZodiacFire())
        }
        if UI.btnZodiacWind && IsObject(UI.btnZodiacWind) {
            try UI.btnZodiacWind.OnEvent("Click", (*) => Controller.ToggleZodiacWind())
        }
        if UI.btnZodiacWater && IsObject(UI.btnZodiacWater) {
            try UI.btnZodiacWater.OnEvent("Click", (*) => Controller.ToggleZodiacWater())
        }
        
        ; Unity Parameters input handlers
        if UI.inputTimeWarpWaitTime && IsObject(UI.inputTimeWarpWaitTime) {
            try UI.inputTimeWarpWaitTime.OnEvent("Change", (*) => Controller.UpdateTimeWarpWaitTime())
            try UI.inputTimeWarpWaitTime.OnEvent("LoseFocus", (*) => Controller.ValidateTimeWarpWaitTime())
        }
        if UI.inputTimeWarpReps && IsObject(UI.inputTimeWarpReps) {
            try UI.inputTimeWarpReps.OnEvent("Change", (*) => Controller.UpdateTimeWarpReps())
            try UI.inputTimeWarpReps.OnEvent("LoseFocus", (*) => Controller.ValidateTimeWarpReps())
        }
        if UI.inputAutoUnityMaxReps && IsObject(UI.inputAutoUnityMaxReps) {
            try UI.inputAutoUnityMaxReps.OnEvent("Change", (*) => Controller.UpdateAutoUnityMaxReps())
            try UI.inputAutoUnityMaxReps.OnEvent("LoseFocus", (*) => Controller.ValidateAutoUnityMaxReps())
        }
        if UI.inputZodiacRedistributionWait && IsObject(UI.inputZodiacRedistributionWait) {
            try UI.inputZodiacRedistributionWait.OnEvent("Change", (*) => Controller.UpdateZodiacRedistributionWait())
            try UI.inputZodiacRedistributionWait.OnEvent("LoseFocus", (*) => Controller.ValidateZodiacRedistributionWait())
        }
        
        ; Input field change handlers
        if UI.inputMineralLevel && IsObject(UI.inputMineralLevel) {
            try UI.inputMineralLevel.OnEvent("Change", (*) => Controller.UpdateMineralLevel())
            try UI.inputMineralLevel.OnEvent("LoseFocus", (*) => Controller.ValidateMineralLevel())
        }
        if UI.inputMergeWait && IsObject(UI.inputMergeWait) {
            try UI.inputMergeWait.OnEvent("Change", (*) => Controller.UpdateMergeWait())
            try UI.inputMergeWait.OnEvent("LoseFocus", (*) => Controller.ValidateMergeWait())
        }
        if UI.inputMicroDelay && IsObject(UI.inputMicroDelay) {
            try UI.inputMicroDelay.OnEvent("Change", (*) => Controller.UpdateMicroDelay())
            try UI.inputMicroDelay.OnEvent("LoseFocus", (*) => Controller.ValidateMicroDelay())
        }
        if UI.inputTimewarp && IsObject(UI.inputTimewarp) {
            try UI.inputTimewarp.OnEvent("Change", (*) => Controller.UpdateTimewarp())
            try UI.inputTimewarp.OnEvent("LoseFocus", (*) => Controller.ValidateTimewarp())
        }
        if UI.inputTimeWarpMinutesToSpend && IsObject(UI.inputTimeWarpMinutesToSpend) {
            try UI.inputTimeWarpMinutesToSpend.OnEvent("Change", (*) => Controller.UpdateTimeWarpMinutesToSpend())
            try UI.inputTimeWarpMinutesToSpend.OnEvent("LoseFocus", (*) => Controller.ValidateTimeWarpMinutesToSpend())
        }
        if UI.inputExploitWait && IsObject(UI.inputExploitWait) {
            try UI.inputExploitWait.OnEvent("Change", (*) => Controller.UpdateExploitWait())
            try UI.inputExploitWait.OnEvent("LoseFocus", (*) => Controller.ValidateExploitWait())
        }
        if UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn) {
            try UI.inputCustomSpawn.OnEvent("Change", (*) => Controller.UpdateCustomSpawn())
            try UI.inputCustomSpawn.OnEvent("LoseFocus", (*) => Controller.ValidateCustomSpawn())
        }
        if UI.inputCustomPolish && IsObject(UI.inputCustomPolish) {
            try UI.inputCustomPolish.OnEvent("Change", (*) => Controller.UpdateCustomPolish())
            try UI.inputCustomPolish.OnEvent("LoseFocus", (*) => Controller.ValidateCustomPolish())
        }
    }
    
    ; Toggle a collapsible section
    static ToggleSection(section, *) {
        ; Update section state
        State.sectionStates[section] := !State.sectionStates[section]
        
        ; Save current position
        x := 100
        y := 100
        if UI.gui && IsObject(UI.gui) {
            try {
                WinGetPos &x, &y, , , "ahk_id " UI.gui.Hwnd
            } catch {
                x := 100
                y := 100
            }
        }
        
        ; Disable UI updates during recreation
        SetTimer(() => UIManager.Update(), 0)
        
        ; Destroy and recreate GUI
        if UI.gui && IsObject(UI.gui) {
            UI.gui.Destroy()
            UI.gui := 0
        }
        
        ; Reset all control references
        UI.sectionContents.Clear()
        UI.sectionHeaders.Clear()
        UI.sectionBorders.Clear()
        UI.buttonStates.Clear()
        
        ; Recreate GUI with current layout
        UIManager.CreateGUI()
        UIManager.SetupEventHandlers()
        UIManager.UpdateVisuals()
        
        ; Re-enable UI updates
        SetTimer(() => UIManager.Update(), Config.UI_UPDATE_INTERVAL)
        
        ; Restore position
        if UI.gui && IsObject(UI.gui) {
            WinMove x, y, , , "ahk_id " UI.gui.Hwnd
        }
    }
    
    ; Update UI elements periodically
    static Update() {
        if !UI.gui || !IsObject(UI.gui)
            return
        
        ; Check if update is needed and not too frequent
        currentTime := A_TickCount
        if !UI.needsUpdate && (currentTime - UI.lastUpdateTime) < UI.updateInterval
            return
        
        ; Reset dirty flag and update timestamp
        UI.needsUpdate := false
        UI.lastUpdateTime := currentTime
        
        ; Update start/stop button text and style
        on := State.isRunning || State.isStarting
        buttonText := on ? "F5: Stop macro" : "F5: Start macro"
        if UI.btnStartStop && IsObject(UI.btnStartStop) {
            try {
                if UI.btnStartStop.Text != buttonText {
                    UI.btnStartStop.Text := buttonText
                    UIManager.UpdateButtonStyle(UI.btnStartStop, on)
                }
            }
        }
        
        ; Update screenshot preview
        if UI.imgPreview && IsObject(UI.imgPreview) && State.lastScreenshotPath && FileExist(State.lastScreenshotPath) {
            try UI.imgPreview.Value := State.lastScreenshotPath
        }
        
        ; Update cycle statistics
        if UI.lblStatistics && IsObject(UI.lblStatistics) {
            try UI.lblStatistics.Text := Format("Cycles: {}", State.cycleCount)
        }
        
        ; Update average cycle time
        if UI.lblCycleTime && IsObject(UI.lblCycleTime) {
            try {
                if State.cycleTimes.Length > 0 {
                    totalTime := 0
                    for time in State.cycleTimes
                        totalTime += time
                    avgTime := totalTime / State.cycleTimes.Length
                    UI.lblCycleTime.Text := Format("Avg cycle: {}", Util.FormatTime(Round(avgTime)))
                } else {
                    UI.lblCycleTime.Text := "Avg cycle: --:--:--:-"
                }
            }
        }
        
        ; Update header animation when macro is running
        if State.isRunning {
            try {
                ; Hide normal header elements
                if UI.titleText
                    UI.titleText.Opt("+Hidden")
                if UI.btnEye
                    UI.btnEye.Opt("+Hidden")
                if UI.btnClose
                    UI.btnClose.Opt("+Hidden")
                    
                ; Show animated elements
                if UI.headerLeft
                    UI.headerLeft.Opt("-Hidden")
                if UI.headerRight
                    UI.headerRight.Opt("-Hidden")
                
                ; Update timer display
                elapsed := A_TickCount - State.startTime
                if UI.headerRight
                    UI.headerRight.Text := Util.FormatTime(elapsed)
                
                ; Animate "Running..." text
                phase := Mod((A_TickCount // 400), 5)
                dots := ""
                Loop phase
                    dots .= "."
                if UI.headerLeft
                    UI.headerLeft.Text := "Running" dots
            }
        } else {
            try {
                ; Hide animated elements
                if UI.headerLeft
                    UI.headerLeft.Opt("+Hidden")
                if UI.headerRight
                    UI.headerRight.Opt("+Hidden")
                    
                ; Show normal header elements
                if UI.titleText
                    UI.titleText.Opt("-Hidden")
                if UI.btnEye
                    UI.btnEye.Opt("-Hidden")
                if UI.btnClose
                    UI.btnClose.Opt("-Hidden")
            }
        }
    }
    
    ; Update button visual style
    static UpdateButtonStyle(btn, isActive) {
        if !btn || !IsObject(btn)
            return
        
        try {
            UI.buttonStates[btn.Hwnd] := isActive
            
            if isActive {
                ; Active button: white background, black text
                btn.Opt("+BackgroundFFFFFF")
                btn.SetFont("s10 c000000", "Cascadia Mono")
            } else {
                ; Inactive button: black background, white text
                btn.Opt("+Background000000")
                btn.SetFont("s10 cFFFFFF", "Cascadia Mono")
            }
        }
    }
    
    ; Update all button visuals based on current state
    static UpdateVisuals() {
        ; Update macro buttons
        if UI.btnMacroStandard && IsObject(UI.btnMacroStandard)
            UIManager.UpdateButtonStyle(UI.btnMacroStandard, State.currentMacro = "standard")
        if UI.btnMacroQuick && IsObject(UI.btnMacroQuick)
            UIManager.UpdateButtonStyle(UI.btnMacroQuick, State.currentMacro = "quick")
        if UI.btnMacroLong && IsObject(UI.btnMacroLong)
            UIManager.UpdateButtonStyle(UI.btnMacroLong, State.currentMacro = "long")
        if UI.btnMacroEndgame && IsObject(UI.btnMacroEndgame)
            UIManager.UpdateButtonStyle(UI.btnMacroEndgame, State.currentMacro = "endgame")
        if UI.btnMacroTimeWarp && IsObject(UI.btnMacroTimeWarp)
            UIManager.UpdateButtonStyle(UI.btnMacroTimeWarp, State.currentMacro = "timewarp")
        if UI.btnMacroAutoClicker && IsObject(UI.btnMacroAutoClicker)
            UIManager.UpdateButtonStyle(UI.btnMacroAutoClicker, State.currentMacro = "autoclicker")
        if UI.btnMacroTimeFluxBuy && IsObject(UI.btnMacroTimeFluxBuy)
            UIManager.UpdateButtonStyle(UI.btnMacroTimeFluxBuy, State.currentMacro = "timefluxbuy")
        if UI.btnMacroAutoUnity && IsObject(UI.btnMacroAutoUnity)
            UIManager.UpdateButtonStyle(UI.btnMacroAutoUnity, State.currentMacro = "autounity")
        if UI.btnMacroZodiacRedistribution && IsObject(UI.btnMacroZodiacRedistribution)
            UIManager.UpdateButtonStyle(UI.btnMacroZodiacRedistribution, State.currentMacro = "zodiacredistribution")
        
        ; Update game state buttons and inputs
        if UI.btnStateEarly && IsObject(UI.btnStateEarly)
            UIManager.UpdateButtonStyle(UI.btnStateEarly, State.gameState = "early")
        if UI.btnStateMid && IsObject(UI.btnStateMid)
            UIManager.UpdateButtonStyle(UI.btnStateMid, State.gameState = "mid")
        if UI.btnStateLate && IsObject(UI.btnStateLate)
            UIManager.UpdateButtonStyle(UI.btnStateLate, State.gameState = "late")
        if UI.btnStateCustom && IsObject(UI.btnStateCustom)
            UIManager.UpdateButtonStyle(UI.btnStateCustom, State.gameState = "custom")
        
        ; Update custom spawn/polish inputs based on game state
        if UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn) {
            switch State.gameState {
                case "early":
                    try UI.inputCustomSpawn.Text := "7"
                case "mid":
                    try UI.inputCustomSpawn.Text := "5"
                case "late":
                    try UI.inputCustomSpawn.Text := "4"
            }
        }
        if UI.inputCustomPolish && IsObject(UI.inputCustomPolish) {
            switch State.gameState {
                case "early":
                    try UI.inputCustomPolish.Text := "3"
                case "mid":
                    try UI.inputCustomPolish.Text := "2"
                case "late":
                    try UI.inputCustomPolish.Text := "1"
            }
        }
        
        ; Update Fine Settings buttons
        if UI.btnToggleRefining && IsObject(UI.btnToggleRefining)
            UIManager.UpdateButtonStyle(UI.btnToggleRefining, State.autoRefining)
        if UI.btnToggleRftUpgrade && IsObject(UI.btnToggleRftUpgrade)
            UIManager.UpdateButtonStyle(UI.btnToggleRftUpgrade, State.autoRftUpgrade)
        if UI.btnTogglePolishMode && IsObject(UI.btnTogglePolishMode)
            UIManager.UpdateButtonStyle(UI.btnTogglePolishMode, State.allWeaponsPolish)
        
        ; Update Automation Unlockables buttons
        if UI.btnToggleAutospawn && IsObject(UI.btnToggleAutospawn)
            UIManager.UpdateButtonStyle(UI.btnToggleAutospawn, State.autospawnUnlocked)
        if UI.btnToggleAutomerge && IsObject(UI.btnToggleAutomerge)
            UIManager.UpdateButtonStyle(UI.btnToggleAutomerge, State.automergeUnlocked)
        if UI.btnToggleAutoMaxLevel && IsObject(UI.btnToggleAutoMaxLevel)
            UIManager.UpdateButtonStyle(UI.btnToggleAutoMaxLevel, State.autoMaxLevelUnlocked)
        if UI.btnToggleAutoWeaponPolish && IsObject(UI.btnToggleAutoWeaponPolish)
            UIManager.UpdateButtonStyle(UI.btnToggleAutoWeaponPolish, State.autoWeaponPolishUnlocked)
            
        ; Update Unity Parameters buttons
        if UI.btnZodiacEarth && IsObject(UI.btnZodiacEarth)
            UIManager.UpdateButtonStyle(UI.btnZodiacEarth, State.zodiacEarth)
        if UI.btnZodiacFire && IsObject(UI.btnZodiacFire)
            UIManager.UpdateButtonStyle(UI.btnZodiacFire, State.zodiacFire)
        if UI.btnZodiacWind && IsObject(UI.btnZodiacWind)
            UIManager.UpdateButtonStyle(UI.btnZodiacWind, State.zodiacWind)
        if UI.btnZodiacWater && IsObject(UI.btnZodiacWater)
            UIManager.UpdateButtonStyle(UI.btnZodiacWater, State.zodiacWater)
    }
    
    ; Handle window dragging
    static OnDrag(wParam, lParam, msg, hwnd) {
        if !UI.gui || !IsObject(UI.gui) || State.isRunning
            return
        
        ; Check if clicking on compact window
        if UI.isCompact && UI.compactGui && IsObject(UI.compactGui) {
            if hwnd = UI.compactGui.Hwnd {
                PostMessage 0xA1, 2, 0,, "ahk_id " UI.compactGui.Hwnd
                return
            }
        }
        
        ; Check if clicking on main window
        try {
            root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
            if root != UI.gui.Hwnd
                return
        } catch {
            return
        }
        
        ; Don't drag if clicking on interactive controls
        for section, header in UI.sectionHeaders {
            if header && IsObject(header) && hwnd = header.Hwnd
                return
        }
        
        ; Check all buttons - only check if they exist
        buttons := []
        
        ; Add buttons only if they exist
        if UI.btnEye && IsObject(UI.btnEye)
            buttons.Push(UI.btnEye)
        if UI.btnClose && IsObject(UI.btnClose)
            buttons.Push(UI.btnClose)
        if UI.btnStartStop && IsObject(UI.btnStartStop)
            buttons.Push(UI.btnStartStop)
            
        ; Check controls from all sections
        for section, controls in UI.sectionContents {
            for ctrl in controls {
                try {
                    if IsObject(ctrl) && ctrl.Hwnd && hwnd = ctrl.Hwnd
                        return
                } catch {
                    ; Control might be destroyed, continue
                }
            }
        }
        
        for btn in buttons {
            try {
                if IsObject(btn) && btn.Hwnd && hwnd = btn.Hwnd
                    return
            } catch {
                ; Control might be destroyed, continue
            }
        }
        
        ; Check input fields
        inputs := []
        if UI.inputMineralLevel && IsObject(UI.inputMineralLevel)
            inputs.Push(UI.inputMineralLevel)
        if UI.inputMergeWait && IsObject(UI.inputMergeWait)
            inputs.Push(UI.inputMergeWait)
        if UI.inputMicroDelay && IsObject(UI.inputMicroDelay)
            inputs.Push(UI.inputMicroDelay)
        if UI.inputTimewarp && IsObject(UI.inputTimewarp)
            inputs.Push(UI.inputTimewarp)
        if UI.inputTimeWarpMinutesToSpend && IsObject(UI.inputTimeWarpMinutesToSpend)
            inputs.Push(UI.inputTimeWarpMinutesToSpend)
        if UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn)
            inputs.Push(UI.inputCustomSpawn)
        if UI.inputCustomPolish && IsObject(UI.inputCustomPolish)
            inputs.Push(UI.inputCustomPolish)
            
        for input in inputs {
            try {
                if IsObject(input) && input.Hwnd && hwnd = input.Hwnd
                    return
            } catch {
                ; Control might be destroyed, continue
            }
        }
        
        ; Allow dragging the window
        try {
            PostMessage 0xA1, 2, 0,, "ahk_id " UI.gui.Hwnd
        }
    }
}

; ================================================================================
; COORDINATE PICKER
; ================================================================================

class CoordinatePicker {
    ; Static properties
    static instrGui := ""
    static currentListView := ""
    static currentRowNum := 0
    
    ; Start picking a coordinate from ListView
    static StartPickingWithListView(coordName, listView, rowNum) {
        if State.isPickingCoordinate {
            CoordinatePicker.StopPicking()
        }
        
        State.isPickingCoordinate := true
        State.currentCoordinateName := coordName
        CoordinatePicker.currentListView := listView
        CoordinatePicker.currentRowNum := rowNum
        
        ; Switch main HUD to compact mode and get its position
        UIManager.ToggleCompact()  ; Switch to compact mode
        UI.gui.GetPos(&guiX, &guiY, &guiW, &guiH)
        
        ; Create instruction GUI with white background
        instrGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Border", "Coordinate Picker")
        instrGui.BackColor := "FFFFFF"  ; White background for the entire GUI
        instrGui.MarginX := 0
        instrGui.MarginY := 0
        instrGui.SetFont("s9 c000000", "Cascadia Mono")  ; Black text on white background
        
        ; Calculate dimensions for single line of text
        headerH := 42   ; Same as HUD header height
        headerW := 800  ; Extra wide for longer coordinate names
        
        ; Get compact HUD dimensions (eye icon size)
        compactSize := 24  ; Compact HUD is just a 24px eye icon
        
        ; Position to the right of compact HUD, or left if right doesn't fit
        rightX := guiX + compactSize + 25  ; 25px gap to the right of compact HUD (not full HUD)
        leftX := guiX - headerW - 10  ; 10px gap to the left of compact HUD
        
        ; Check if right position fits on screen, otherwise use left
        screenW := SysGet(16)  ; Get screen width to check positioning bounds
        instrX := (rightX + headerW <= screenW) ? rightX : leftX
        instrY := guiY - 1  ; 1px higher than HUD
        
        ; Create single instruction text
        instrText := "Click anywhere to set " . coordName . " coordinate, Esc to cancel"
        
        ; Add centered instruction text
        mainText := instrGui.AddText(Format("x8 y{} w{} h26 Center", (headerH - 26) // 2, headerW - 16), instrText)
        mainText.SetFont("s9 Bold c000000", "Cascadia Mono")  ; Size 9, Bold, Black text
        
        ; Show instruction GUI
        instrGui.Show(Format("x{} y{} w{} h{} NoActivate", instrX, instrY, headerW, headerH))
        
        ; Automatically activate Revolution Idle window
        try {
            WinActivate(Config.TARGET_PROCESS)
        } catch {
            ; If exact process name fails, try partial match
            try {
                WinActivate("Revolution Idle")
            }
        }
        
        ; Set up click capture hotkey
        State.coordinatePickerHotkey := "LButton"
        Hotkey("~LButton", CoordinatePicker.CaptureClick, "On")
        
        ; Store instruction GUI reference for cleanup
        CoordinatePicker.instrGui := instrGui
    }
    
    ; Handle ListView double-click event
    static HandleListViewDoubleClick(listView) {
        selectedRow := listView.GetNext()
        if selectedRow > 0 {
            coordName := listView.GetText(selectedRow, 1)
            CoordinatePicker.StartPickingWithListView(coordName, listView, selectedRow)
        }
    }
    
    ; Legacy method for backward compatibility
    static StartPicking(coordName) {
        CoordinatePicker.StartPickingWithListView(coordName, UI.coordListView, 0)
    }
    
    ; Capture the clicked coordinate
    static CaptureClick(*) {
        if !State.isPickingCoordinate
            return
            
        ; Add small delay to avoid capturing the instruction GUI click
        Sleep 100
        
        ; Get mouse position
        MouseGetPos(&mouseX, &mouseY)
        
        ; Display coordinates to user
        ToolTip("Captured: " . State.currentCoordinateName . " at (" . mouseX . ", " . mouseY . ")")
        SetTimer(() => ToolTip(), -2000)  ; Clear after 2 seconds
        
        ; Update the coordinate in State.coords
        State.coords[State.currentCoordinateName] := [mouseX, mouseY]
        
        ; Save to config file
        ini := Config.CONFIG_FILE
        IniWrite(mouseX, ini, "Coordinates", State.currentCoordinateName . "_X")
        IniWrite(mouseY, ini, "Coordinates", State.currentCoordinateName . "_Y")
        
        ; Update ListView if we have a reference
        if CoordinatePicker.currentListView {
            try {
                ; Find the row with this coordinate name and update it
                rowCount := CoordinatePicker.currentListView.GetCount()
                Loop rowCount {
                    if CoordinatePicker.currentListView.GetText(A_Index, 1) = State.currentCoordinateName {
                        ; Update columns 2 (X) and 3 (Y) with captured coordinates
                        CoordinatePicker.currentListView.Modify(A_Index, , , mouseX, mouseY)
                        break
                    }
                }
            }
        }
        
        ; Force close the instruction GUI immediately
        if CoordinatePicker.instrGui {
            try {
                CoordinatePicker.instrGui.Destroy()  ; Use Destroy() instead of Close()
            }
            CoordinatePicker.instrGui := ""
        }
        
        CoordinatePicker.StopPicking()
    }
    
    ; Stop coordinate picking
    static StopPicking(*) {
        if !State.isPickingCoordinate
            return
            
        State.isPickingCoordinate := false
        State.currentCoordinateName := ""
        CoordinatePicker.currentListView := ""
        CoordinatePicker.currentRowNum := 0
        
        ; Clean up hotkeys
        try {
            Hotkey("~LButton", CoordinatePicker.CaptureClick, "Off")
        }
        
        ; Close instruction GUI (if not already closed)
        if CoordinatePicker.instrGui {
            try {
                CoordinatePicker.instrGui.Destroy()  ; Use Destroy() for complete cleanup
            } catch {
                ; GUI might already be destroyed
            }
            CoordinatePicker.instrGui := ""
        }
        
        ; Restore HUD from compact mode back to full mode
        UIManager.ToggleCompact()  ; Switch back to full mode
    }
}

; ================================================================================
; MAIN CONTROLLER
; ================================================================================

class Controller {
    ; Toggle macro start/stop
    static ToggleStart() {
        if State.isRunning {
            Controller.Stop()
        } else if !State.isStopping && !State.isLocked {
            Controller.Start()
        }
    }
    
    ; Start the macro
    static Start() {
        UIManager.Initialize()
        Screenshot.InitGDI()
        
        if State.isRunning || State.isLocked
            return
        
        ; Check if game is running
        if !WinExist("ahk_exe " Config.TARGET_PROCESS) {
            ToolTip "Target process not found: " Config.TARGET_PROCESS, 10, 10
            SetTimer(() => ToolTip(), -1500)
            return
        }
        
        ; Reset statistics
        State.cycleTimes := []
        State.lastCycleEnd := A_TickCount
        
        ; Focus game and start macro
        Util.FocusGame(true)
        Controller.RunMacro()
    }
    
    ; Stop the macro
    static Stop() {
        if State.isStopping
            return
        
        State.isStopping := true
        State.isRunning := false
        State.isStarting := false
        
        ; Immediately restore window interactivity
        try {
            if UI.gui && IsObject(UI.gui) {
                WinSetExStyle("-0x80020", "ahk_id " UI.gui.Hwnd)
                WinSetTransparent("Off", "ahk_id " UI.gui.Hwnd)
            }
        }
        
        UIManager.Update()
        SetTimer(() => Controller.WaitStop(), -10)
    }
    
    ; Wait for macro to fully stop
    static WaitStop() {
        t0 := A_TickCount
        while State.isLocked && (A_TickCount - t0 < 300)  ; 300ms timeout for stop completion
            Sleep 10
        State.isLocked := false
        State.isStopping := false
        State.isStarting := false
        
        ; Restore window properties and interactivity
        try {
            if UI.gui && IsObject(UI.gui) {
                WinSetExStyle("-0x80020", "ahk_id " UI.gui.Hwnd)  ; Remove click-through
                WinSetTransparent("Off", "ahk_id " UI.gui.Hwnd)   ; Remove transparency
                ; Force window to be interactive
                WinActivate("ahk_id " UI.gui.Hwnd)
            }
        }
        
        UIManager.Update()
    }
    
    ; Main macro execution loop
    static RunMacro() {
        State.isRunning := true
        State.isLocked := true
        State.cycleCount := 0
        State.autoUnityCount := 0  ; Reset Auto Unity counter
        State.startTime := A_TickCount
        
        UIManager.Update()
        
        ; Make window click-through during macro
        try {
            if UI.gui && IsObject(UI.gui) {
                WinSetExStyle("+0x80020", "ahk_id " UI.gui.Hwnd)
                WinSetTransparent(180, "ahk_id " UI.gui.Hwnd)
            }
        }
        
        try {
            ; Main macro loop
            while State.isRunning {
                if Util.IsGameBlocked() {
                    Util.Sleep(80)
                    continue
                }
                
                ; Check Auto Unity loop limit
                if (State.currentMacro = "autounity" && State.autoUnityCount >= (IsNumber(State.autoUnityMaxReps) ? State.autoUnityMaxReps : 76)) {
                    State.isRunning := false
                    break
                }
                
                ; Execute selected macro
                switch State.currentMacro {
                    case "quick":
                        Macro.Quick()
                    case "long":
                        Macro.Long()
                    case "endgame":
                        Macro.Endgame()
                    case "timewarp":
                        Macro.TimeWarp()
                    case "autoclicker":
                        Macro.AutoClicker()
                    case "timefluxbuy":
                        Macro.TimeFluxBuy()
                    case "autounity":
                        Macro.AutoUnity()
                        State.autoUnityCount++
                    case "zodiacredistribution":
                        Macro.ZodiacRedistribution()
                    default:
                        Macro.Standard()
                }
            }
        } finally {
            ; Restore window properties
            try {
                if UI.gui && IsObject(UI.gui) {
                    WinSetExStyle("-0x80020", "ahk_id " UI.gui.Hwnd)
                    WinSetTransparent("Off", "ahk_id " UI.gui.Hwnd)
                }
            }
            State.isLocked := false
            UIManager.Update()
        }
    }
    
    ; Select a macro type
    static SelectMacro(macro) {
        State.currentMacro := macro
        UI.MarkDirty()
        UIManager.UpdateVisuals()
        Util.FocusGame()
    }
    
    ; Cycle through macro types
    static CycleMacro() {
        macros := ["standard", "quick", "long", "timewarp", "autoclicker", "endgame", "timefluxbuy", "autounity", "zodiacredistribution"]
        currentIndex := 1
        for i, m in macros {
            if m = State.currentMacro {
                currentIndex := i
                break
            }
        }
        nextIndex := currentIndex = Constants.MAX_MACRO_COUNT ? 1 : currentIndex + 1
        Controller.SelectMacro(macros[nextIndex])
    }
    
    ; Select game state
    static SelectGameState(gameState) {
        State.gameState := gameState
        UIManager.UpdateVisuals()
        Util.FocusGame()
    }
    
    ; Cycle through game states
    static CycleGameState() {
        states := ["early", "mid", "late", "custom"]
        currentIndex := 1
        for i, s in states {
            if s = State.gameState {
                currentIndex := i
                break
            }
        }
        nextIndex := currentIndex = 4 ? 1 : currentIndex + 1
        Controller.SelectGameState(states[nextIndex])
    }
    
    ; Toggle all Fine Settings at once
    static ToggleAllFineSettings() {
        ; If any are disabled, enable all; otherwise disable all
        anyDisabled := !State.autoRefining || !State.autoRftUpgrade || !State.allWeaponsPolish
        
        State.autoRefining := anyDisabled
        State.autoRftUpgrade := anyDisabled
        State.allWeaponsPolish := anyDisabled
        
        ; Update UI
        if UI.btnToggleRefining && IsObject(UI.btnToggleRefining) {
            UI.btnToggleRefining.Text := State.autoRefining ? "Auto Refining" : "No Refining"
            UIManager.UpdateButtonStyle(UI.btnToggleRefining, State.autoRefining)
        }
        if UI.btnToggleRftUpgrade && IsObject(UI.btnToggleRftUpgrade) {
            UI.btnToggleRftUpgrade.Text := State.autoRftUpgrade ? "Auto RfT Upg" : "No RfT Upg"
            UIManager.UpdateButtonStyle(UI.btnToggleRftUpgrade, State.autoRftUpgrade)
        }
        if UI.btnTogglePolishMode && IsObject(UI.btnTogglePolishMode) {
            UI.btnTogglePolishMode.Text := State.allWeaponsPolish ? "All Weapons Polish" : "Sword Polish Only"
            UIManager.UpdateButtonStyle(UI.btnTogglePolishMode, State.allWeaponsPolish)
        }
        
        Util.FocusGame()
    }
    
    ; Toggle all Automation Unlockables at once
    static ToggleAllUnlockables() {
        ; If any are locked, unlock all; otherwise lock all
        anyLocked := !State.autospawnUnlocked || !State.automergeUnlocked || 
                    !State.autoMaxLevelUnlocked || !State.autoWeaponPolishUnlocked
        
        State.autospawnUnlocked := anyLocked
        State.automergeUnlocked := anyLocked
        State.autoMaxLevelUnlocked := anyLocked
        State.autoWeaponPolishUnlocked := anyLocked
        
        ; Update UI
        if UI.btnToggleAutospawn && IsObject(UI.btnToggleAutospawn) {
            UI.btnToggleAutospawn.Text := State.autospawnUnlocked ? "Autospawn UNLOCKED" : "Autospawn LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutospawn, State.autospawnUnlocked)
        }
        if UI.btnToggleAutomerge && IsObject(UI.btnToggleAutomerge) {
            UI.btnToggleAutomerge.Text := State.automergeUnlocked ? "Automerge UNLOCKED" : "Automerge LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutomerge, State.automergeUnlocked)
        }
        if UI.btnToggleAutoMaxLevel && IsObject(UI.btnToggleAutoMaxLevel) {
            UI.btnToggleAutoMaxLevel.Text := State.autoMaxLevelUnlocked ? "Auto Max Lvl UNLOCKED" : "Auto Max Lvl LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutoMaxLevel, State.autoMaxLevelUnlocked)
        }
        if UI.btnToggleAutoWeaponPolish && IsObject(UI.btnToggleAutoWeaponPolish) {
            UI.btnToggleAutoWeaponPolish.Text := State.autoWeaponPolishUnlocked ? "Auto Wpn Polish UNLOCKED" : "Auto Wpn Polish LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutoWeaponPolish, State.autoWeaponPolishUnlocked)
        }
        
        Util.FocusGame()
    }
    
    ; Update functions for input fields
    static UpdateMineralLevel() {
        if UI.inputMineralLevel && IsObject(UI.inputMineralLevel) {
            newVal := UI.inputMineralLevel.Text
            if newVal != State.mineralLevel {
                State.mineralLevel := newVal
            }
        }
    }
    
    static UpdateMergeWait() {
        if UI.inputMergeWait && IsObject(UI.inputMergeWait) {
            newVal := UI.inputMergeWait.Text
            if newVal != State.mergeWaitTime {
                State.mergeWaitTime := newVal
            }
        }
    }
    
    static UpdateMicroDelay() {
        if UI.inputMicroDelay && IsObject(UI.inputMicroDelay) {
            newVal := UI.inputMicroDelay.Text
            if RegExMatch(newVal, "^\d+$") {
                numVal := newVal + 0
                if numVal > 0 && numVal != State.microDelayMs {
                    State.microDelayMs := numVal
                    }
            }
        }
    }
    
    static UpdateTimewarp() {
        if UI.inputTimewarp && IsObject(UI.inputTimewarp) {
            newVal := UI.inputTimewarp.Text
            if newVal != State.timewarpInterval {
                State.timewarpInterval := newVal
            }
        }
    }
    
    static UpdateTimeWarpMinutesToSpend() {
        if UI.inputTimeWarpMinutesToSpend && IsObject(UI.inputTimeWarpMinutesToSpend) {
            newVal := UI.inputTimeWarpMinutesToSpend.Text
            if newVal != State.timeWarpMinutesToSpend {
                State.timeWarpMinutesToSpend := newVal
            }
        }
    }
    
    static UpdateExploitWait() {
        if UI.inputExploitWait && IsObject(UI.inputExploitWait) {
            newVal := UI.inputExploitWait.Text
            if newVal != State.exploitWaitTime {
                State.exploitWaitTime := newVal
            }
        }
    }
    
    static UpdateCustomSpawn() {
        if UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn) {
            newVal := UI.inputCustomSpawn.Text
            if newVal != State.customSpawnReps && newVal != "" {
                State.customSpawnReps := newVal
                
                ; Auto-select custom state if values don't match preset states
                ; Only process if values are numeric
                if (RegExMatch(newVal, "^\d+$") && UI.inputCustomPolish && IsObject(UI.inputCustomPolish) && RegExMatch(UI.inputCustomPolish.Text, "^\d+$")) {
                    spawn := newVal + 0
                    polish := UI.inputCustomPolish.Text + 0
                    
                    if !((spawn = 7 && polish = 3) || (spawn = 5 && polish = 2) || (spawn = 4 && polish = 1)) {
                        State.gameState := "custom"
                        UIManager.UpdateVisuals()
                    }
                }
                
            }
        }
    }
    
    static UpdateCustomPolish() {
        if UI.inputCustomPolish && IsObject(UI.inputCustomPolish) {
            newVal := UI.inputCustomPolish.Text
            if newVal != State.customPolishReps && newVal != "" {
                State.customPolishReps := newVal
                
                ; Auto-select custom state if values don't match preset states
                ; Only process if values are numeric
                if (RegExMatch(newVal, "^\d+$") && UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn) && RegExMatch(UI.inputCustomSpawn.Text, "^\d+$")) {
                    spawn := UI.inputCustomSpawn.Text + 0
                    polish := newVal + 0
                    
                    if !((spawn = 7 && polish = 3) || (spawn = 5 && polish = 2) || (spawn = 4 && polish = 1)) {
                        State.gameState := "custom"
                        UIManager.UpdateVisuals()
                    }
                }
                
            }
        }
    }
    
    ; Validation functions to restore defaults if empty
    static ValidateMineralLevel() {
        if UI.inputMineralLevel && IsObject(UI.inputMineralLevel) {
            if UI.inputMineralLevel.Text = "" || !RegExMatch(UI.inputMineralLevel.Text, "^\d+$") {
                UI.inputMineralLevel.Text := "999"
                State.mineralLevel := "999"
            }
        }
    }
    
    static ValidateMergeWait() {
        if UI.inputMergeWait && IsObject(UI.inputMergeWait) {
            if UI.inputMergeWait.Text = "" || !RegExMatch(UI.inputMergeWait.Text, "^\d+$") {
                UI.inputMergeWait.Text := "5000"
                State.mergeWaitTime := "5000"
            }
        }
    }
    
    static ValidateMicroDelay() {
        if UI.inputMicroDelay && IsObject(UI.inputMicroDelay) {
            if UI.inputMicroDelay.Text = "" || !RegExMatch(UI.inputMicroDelay.Text, "^\d+$") {
                UI.inputMicroDelay.Text := "25"
                State.microDelayMs := 25
            }
        }
    }
    
    static ValidateTimewarp() {
        if UI.inputTimewarp && IsObject(UI.inputTimewarp) {
            if UI.inputTimewarp.Text = "" || !RegExMatch(UI.inputTimewarp.Text, "^\d+$") {
                UI.inputTimewarp.Text := "1000"
                State.timewarpInterval := "1000"
            }
        }
    }
    
    static ValidateTimeWarpMinutesToSpend() {
        if UI.inputTimeWarpMinutesToSpend && IsObject(UI.inputTimeWarpMinutesToSpend) {
            if UI.inputTimeWarpMinutesToSpend.Text = "" || !RegExMatch(UI.inputTimeWarpMinutesToSpend.Text, "^\d+$") {
                UI.inputTimeWarpMinutesToSpend.Text := "10"
                State.timeWarpMinutesToSpend := "10"
            }
        }
    }
    
    static ValidateExploitWait() {
        if UI.inputExploitWait && IsObject(UI.inputExploitWait) {
            if UI.inputExploitWait.Text = "" || !RegExMatch(UI.inputExploitWait.Text, "^\d+$") {
                UI.inputExploitWait.Text := "5000"
                State.exploitWaitTime := "5000"
            }
        }
    }
    
    static ValidateCustomSpawn() {
        if UI.inputCustomSpawn && IsObject(UI.inputCustomSpawn) {
            if UI.inputCustomSpawn.Text = "" || !RegExMatch(UI.inputCustomSpawn.Text, "^\d+$") {
                UI.inputCustomSpawn.Text := "4"
                State.customSpawnReps := "4"
            }
        }
    }
    
    static ValidateCustomPolish() {
        if UI.inputCustomPolish && IsObject(UI.inputCustomPolish) {
            if UI.inputCustomPolish.Text = "" || !RegExMatch(UI.inputCustomPolish.Text, "^\d+$") {
                UI.inputCustomPolish.Text := "1"
                State.customPolishReps := "1"
            }
        }
    }
    
    ; Unity Parameters input functions
    static UpdateTimeWarpWaitTime() {
        if UI.inputTimeWarpWaitTime && IsObject(UI.inputTimeWarpWaitTime) {
            newVal := UI.inputTimeWarpWaitTime.Text
            if RegExMatch(newVal, "^\d+$") {
                numVal := newVal + 0
                if numVal > 0 && numVal != State.timeWarpWaitTime {
                    State.timeWarpWaitTime := newVal
                    }
            }
        }
    }
    
    static ValidateTimeWarpWaitTime() {
        if UI.inputTimeWarpWaitTime && IsObject(UI.inputTimeWarpWaitTime) {
            if UI.inputTimeWarpWaitTime.Text = "" || !RegExMatch(UI.inputTimeWarpWaitTime.Text, "^\d+$") {
                UI.inputTimeWarpWaitTime.Text := "5000"
                State.timeWarpWaitTime := "5000"
            }
        }
    }
    
    static UpdateTimeWarpReps() {
        if UI.inputTimeWarpReps && IsObject(UI.inputTimeWarpReps) {
            newVal := UI.inputTimeWarpReps.Text
            if RegExMatch(newVal, "^\d+$") {
                numVal := newVal + 0
                if numVal > 0 && numVal != State.timeWarpReps {
                    State.timeWarpReps := newVal
                    }
            }
        }
    }
    
    static ValidateTimeWarpReps() {
        if UI.inputTimeWarpReps && IsObject(UI.inputTimeWarpReps) {
            if UI.inputTimeWarpReps.Text = "" || !RegExMatch(UI.inputTimeWarpReps.Text, "^\d+$") {
                UI.inputTimeWarpReps.Text := "1"
                State.timeWarpReps := "1"
            }
        }
    }
    
    static UpdateAutoUnityMaxReps() {
        if UI.inputAutoUnityMaxReps && IsObject(UI.inputAutoUnityMaxReps) {
            newVal := UI.inputAutoUnityMaxReps.Text
            if RegExMatch(newVal, "^\d+$") {
                numVal := newVal + 0
                if numVal > 0 && numVal != State.autoUnityMaxReps {
                    State.autoUnityMaxReps := newVal
                }
            }
        }
    }
    
    static ValidateAutoUnityMaxReps() {
        if UI.inputAutoUnityMaxReps && IsObject(UI.inputAutoUnityMaxReps) {
            if UI.inputAutoUnityMaxReps.Text = "" || !RegExMatch(UI.inputAutoUnityMaxReps.Text, "^\d+$") {
                UI.inputAutoUnityMaxReps.Text := "24"
                State.autoUnityMaxReps := "24"
            }
        }
    }
    
    static UpdateZodiacRedistributionWait() {
        if UI.inputZodiacRedistributionWait && IsObject(UI.inputZodiacRedistributionWait) {
            newVal := UI.inputZodiacRedistributionWait.Text
            if RegExMatch(newVal, "^\d+$") {
                numVal := newVal + 0
                if numVal > 0 && numVal != State.zodiacRedistributionWait {
                    State.zodiacRedistributionWait := newVal
                }
            }
        }
    }
    
    static ValidateZodiacRedistributionWait() {
        if UI.inputZodiacRedistributionWait && IsObject(UI.inputZodiacRedistributionWait) {
            if UI.inputZodiacRedistributionWait.Text = "" || !RegExMatch(UI.inputZodiacRedistributionWait.Text, "^\d+$") {
                UI.inputZodiacRedistributionWait.Text := "400"
                State.zodiacRedistributionWait := "400"
            }
        }
    }
    
    ; Individual toggle functions for Fine Settings
    static ToggleRefining() {
        State.autoRefining := !State.autoRefining
        if UI.btnToggleRefining && IsObject(UI.btnToggleRefining) {
            UI.btnToggleRefining.Text := State.autoRefining ? "Auto Refining" : "No Refining"
            UIManager.UpdateButtonStyle(UI.btnToggleRefining, State.autoRefining)
        }
        Util.FocusGame()
    }
    
    static ToggleRftUpgrade() {
        State.autoRftUpgrade := !State.autoRftUpgrade
        if UI.btnToggleRftUpgrade && IsObject(UI.btnToggleRftUpgrade) {
            UI.btnToggleRftUpgrade.Text := State.autoRftUpgrade ? "Auto RfT Upg" : "No RfT Upg"
            UIManager.UpdateButtonStyle(UI.btnToggleRftUpgrade, State.autoRftUpgrade)
        }
        Util.FocusGame()
    }
    
    static TogglePolishMode() {
        State.allWeaponsPolish := !State.allWeaponsPolish
        if UI.btnTogglePolishMode && IsObject(UI.btnTogglePolishMode) {
            UI.btnTogglePolishMode.Text := State.allWeaponsPolish ? "All Weapons Polish" : "Sword Polish Only"
            UIManager.UpdateButtonStyle(UI.btnTogglePolishMode, State.allWeaponsPolish)
        }
        Util.FocusGame()
    }
    
    ; Individual toggle functions for Automation Unlockables
    static ToggleAutospawn() {
        State.autospawnUnlocked := !State.autospawnUnlocked
        if UI.btnToggleAutospawn && IsObject(UI.btnToggleAutospawn) {
            UI.btnToggleAutospawn.Text := State.autospawnUnlocked ? "Autospawn UNLOCKED" : "Autospawn LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutospawn, State.autospawnUnlocked)
        }
        Util.FocusGame()
    }
    
    static ToggleAutomerge() {
        State.automergeUnlocked := !State.automergeUnlocked
        if UI.btnToggleAutomerge && IsObject(UI.btnToggleAutomerge) {
            UI.btnToggleAutomerge.Text := State.automergeUnlocked ? "Automerge UNLOCKED" : "Automerge LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutomerge, State.automergeUnlocked)
        }
        Util.FocusGame()
    }
    
    static ToggleAutoMaxLevel() {
        State.autoMaxLevelUnlocked := !State.autoMaxLevelUnlocked
        if UI.btnToggleAutoMaxLevel && IsObject(UI.btnToggleAutoMaxLevel) {
            UI.btnToggleAutoMaxLevel.Text := State.autoMaxLevelUnlocked ? "Auto Max Lvl UNLOCKED" : "Auto Max Lvl LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutoMaxLevel, State.autoMaxLevelUnlocked)
        }
        Util.FocusGame()
    }
    
    static ToggleAutoWeaponPolish() {
        State.autoWeaponPolishUnlocked := !State.autoWeaponPolishUnlocked
        if UI.btnToggleAutoWeaponPolish && IsObject(UI.btnToggleAutoWeaponPolish) {
            UI.btnToggleAutoWeaponPolish.Text := State.autoWeaponPolishUnlocked ? "Auto Wpn Polish UNLOCKED" : "Auto Wpn Polish LOCKED"
            UIManager.UpdateButtonStyle(UI.btnToggleAutoWeaponPolish, State.autoWeaponPolishUnlocked)
        }
        Util.FocusGame()
    }
    
    ; Unity Parameters toggle functions
    static ToggleZodiacEarth() {
        State.zodiacEarth := !State.zodiacEarth
        if UI.btnZodiacEarth && IsObject(UI.btnZodiacEarth) {
            UIManager.UpdateButtonStyle(UI.btnZodiacEarth, State.zodiacEarth)
        }
        Util.FocusGame()
    }
    
    static ToggleZodiacFire() {
        State.zodiacFire := !State.zodiacFire
        if UI.btnZodiacFire && IsObject(UI.btnZodiacFire) {
            UIManager.UpdateButtonStyle(UI.btnZodiacFire, State.zodiacFire)
        }
        Util.FocusGame()
    }
    
    static ToggleZodiacWind() {
        State.zodiacWind := !State.zodiacWind
        if UI.btnZodiacWind && IsObject(UI.btnZodiacWind) {
            UIManager.UpdateButtonStyle(UI.btnZodiacWind, State.zodiacWind)
        }
        Util.FocusGame()
    }
    
    static ToggleZodiacWater() {
        State.zodiacWater := !State.zodiacWater
        if UI.btnZodiacWater && IsObject(UI.btnZodiacWater) {
            UIManager.UpdateButtonStyle(UI.btnZodiacWater, State.zodiacWater)
        }
        Util.FocusGame()
    }
}

; ================================================================================
; CLEANUP HANDLER
; ================================================================================

OnExit(CleanupAndExit)

CleanupAndExit(ExitReason, ExitCode) {
    try {
        State.isLocked := false
        ConfigManager.Save()
        
        ; Destroy compact GUI if exists
        if UI.compactGui && IsObject(UI.compactGui) {
            UI.compactGui.Destroy()
        }
        
        ; Shutdown GDI+ if initialized
        if UI.gdiToken {
            DllCall("gdiplus\GdiplusShutdown", "ptr", UI.gdiToken)
            UI.gdiToken := 0
        }
    }
}

; ================================================================================
; UTILITY FUNCTIONS
; ================================================================================

; Handle Escape key - cancel coordinate picking if active, otherwise exit app
HandleEscapeKey() {
    if State.isPickingCoordinate {
        CoordinatePicker.StopPicking()
    } else {
        ExitApp()
    }
}

; ================================================================================
; HOTKEYS
; ================================================================================

$F5::Controller.ToggleStart()           ; Start/stop macro
F10::UIManager.ToggleCompact()          ; Toggle compact mode
$Esc::HandleEscapeKey()                  ; Handle Esc key based on current state

; ================================================================================
; INITIALIZATION
; ================================================================================

UIManager.Initialize()
Screenshot.InitGDI()

; ================================================================================
; END OF SCRIPT
; ================================================================================
