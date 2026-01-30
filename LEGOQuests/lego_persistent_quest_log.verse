using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }


# ====================================================================================================================================
# Stores the quest progress per-player - this is persistent data
# ====================================================================================================================================
var GlobalPersistentData_QuestLog : weak_map(player, lego_persistent_quest_log) = map{}

lego_persistent_quest_log<public> := class<persistable><final>:
    CompletedQuests : []string = array{}
    ActiveQuests : []string = array{}

(InAgent : agent).LoadLegoQuestLog()<decides><transacts> : lego_persistent_quest_log =
    var Result : ?lego_persistent_quest_log = false

    if (FoundData := GlobalPersistentData_QuestLog[player[InAgent]]):
        set Result = option{FoundData}
    else:
        set Result = option{lego_persistent_quest_log{}}
        if (InAgent.SaveLegoQuestLog[Result?]) 
        {}

    Result?

# Set the persistent data stored for this player.
(InAgent : agent).SaveLegoQuestLog<public>(InQuestLog : lego_persistent_quest_log)<decides><transacts> : void =
    var Result : logic = false

    if (set GlobalPersistentData_QuestLog[player[InAgent]] = InQuestLog):
        set Result = true
    else:
        Logger: log = log{Channel := lego_quest_log, DefaultLevel := log_level.Normal}
        Logger.Print("Failed to save LEGO_fortplayer_persistence_data.", ?Level := log_level.Error)

    Result?
