using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { LEGO_Grid_Placement }

# Return the persistent data stored for this player. If it does not exist, create a new instance and return it.
(InAgent : agent).GetLEGOFortPlayerPersistenceData<public>(InDevice : creative_device)<decides><transacts> : lego_fortplayer_persistence_data =
    var OutData : ?lego_fortplayer_persistence_data = false
    if:
        LEGOPlayer := InAgent.GetLEGOFortPlayer[InDevice]
        Player := LEGOPlayer.FortPlayer?
    then:
        if (FoundData := GlobalPersistentData_LEGOFortPlayerData[Player]):
            set OutData = option{FoundData}
        else:
            NewData := lego_fortplayer_persistence_data{}
            if (set GlobalPersistentData_LEGOFortPlayerData[Player] = NewData)
            {}
            set OutData = option{NewData}
        
    if (not OutData?):
        Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("Failed to get LEGO_fortplayer_persistence_data.", ?Level := log_level.Error)

    OutData?

# Set the persistent data stored for this player.
(InAgent : agent).SetLEGOFortPlayerPersistenceData<public>(InDevice : creative_device, InPlayerData : lego_fortplayer_persistence_data)<decides><transacts>: void =
    Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
    var Success : logic = false
    if:
        LEGOPlayer := InAgent.GetLEGOFortPlayer[InDevice]
        Player := LEGOPlayer.FortPlayer?
    then:
        if (FitsInPlayerMap[InPlayerData]):
            if (set GlobalPersistentData_LEGOFortPlayerData[Player] = InPlayerData)
            {}
            LEGOPlayer.PersistentDataUpdated(InPlayerData)
            set Success = true
        else:
            Logger.Print("Failed to set LEGO_fortplayer_persistence_data: Data exceeds size limit!", ?Level := log_level.Error)
    else:
        Logger.Print("Failed to save LEGO_fortplayer_persistence_data.", ?Level := log_level.Error)

    Success?

# ============================================================================================================================================
# Persistent Data
# ============================================================================================================================================
var GlobalPersistentData_LEGOFortPlayerData : weak_map(player, lego_fortplayer_persistence_data) = map{}

