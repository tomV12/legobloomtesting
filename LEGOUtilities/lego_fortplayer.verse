using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /Verse.org/Assets }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

using { LEGO_Grid_Placement }

fortplayer_log<public> := class(log_channel):
# ============================================================================================================================================
# Provides data and behavior on a per-player basis. Maintained by lego_fortplayer_manager.
# ============================================================================================================================================
new_lego_fortplayer<constructor><public>(InFortPlayer : ?player, InFortChar : ?fort_character) := lego_fortplayer:
    FortPlayer := InFortPlayer
    FortChar := InFortChar

lego_fortplayer<public> := class<unique>:
    var UUID<public> : int = 0 # Valid ID after Agent leaves the session
    var FortPlayer<public> : ?player = false
    var FortChar<public> : ?fort_character = false

    # Tick behavior
    var StartWithTickEnabled<protected> : logic = false
    var TickRate<protected> : float = 1.0 # In Seconds

    # Use LEGO_fortplayer_team_assigner or your own implementation
    var Team <protected> : ?int = false

    GetTeam<public>()<transacts> : int = 
        if (ValidTeam := Team?):
            return ValidTeam
        else:
            return -1

    SetTeam<public>(InTeam : int) : void = 
        set Team = option{InTeam}

    Logger<protected>: log = log{Channel := fortplayer_log, DefaultLevel := log_level.Normal}


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Default Methods
    # --------------------------------------------------------------------------------------------------------------------------------------------
    OnBegin<protected>()<suspends> : void =
        return

    OnEnd<protected>() : void =
        return

    Tick<protected>()<suspends> : void =
        loop:
            Logger.Print("Tick")
            Sleep(TickRate)

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Persistence Data
    # --------------------------------------------------------------------------------------------------------------------------------------------
    PersistentDataUpdated<public>(InData : lego_fortplayer_persistence_data)<transacts> : void =
        return

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # LEGO_fortplayer_manager Methods
    # --------------------------------------------------------------------------------------------------------------------------------------------
    Init_LEGOFortplayer<public>()<suspends> : void =
        OnBegin()
        if (StartWithTickEnabled?):
            race:
                OnUninitLEGOFortplayer.Await()
                Tick()
        Logger.Print("Initialized LEGO_fortplayer: {UUID}")

    OnUninitLEGOFortplayer<public> : event() = event(){}
    UnInit_LEGOFortplayer<public>()<suspends> : void =
        Logger.Print("Uninitialized LEGO_fortplayer: {UUID}")
        OnUninitLEGOFortplayer.Signal()
        OnEnd()
