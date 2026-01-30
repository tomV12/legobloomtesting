using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

using { LEGO_Grid_Placement }

# ============================================================================================================================================
# Maintains a lego_fortplayer instance for each FortPlayer, meant to provide centralized access to per-player data and behavior.
#                           --- MUST ASSIGN Tag: Tag_lego_fortplayer_manager to the device instance in the level! ---
# ============================================================================================================================================

# Return the assigned lego_fortplayer from any agent, if it exists. 
(InAgent : agent).GetLEGOFortPlayer<public>(InDevice : creative_device)<decides><transacts> : lego_fortplayer =
    var OutLEGOPlayer : ?lego_fortplayer = false    
    if:
        FoundLEGOPlayer := GetLEGOFortPlayerManager[InDevice].GetLEGOFortPlayerFromAgent[InAgent]
        set OutLEGOPlayer = option{FoundLEGOPlayer}
    else:
        Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("GetLEGOFortPlayer failed.", ?Level := log_level.Warning)
    
    OutLEGOPlayer?

# Return all lego_fortplayers of a specific team
GetLEGOFortPlayersByTeam<public>(InDevice : creative_device, InTeam : int)<transacts> : []lego_fortplayer =
    var OutLEGOPlayers : []lego_fortplayer = array{}

    if (FortPlayerManager := GetLEGOFortPlayerManager[InDevice]):
        for (Player : FortPlayerManager.GetAllLEGOFortPlayers(), Player.GetTeam() = InTeam):
            set OutLEGOPlayers += array{Player}

    OutLEGOPlayers

# Get the FortPlayerManager instance from the level using it`s MarkupTag - if it exists.
GetLEGOFortPlayerManager<public>(InDevice : creative_device)<decides><transacts> : lego_fortplayer_manager =
    var OutObject : ?lego_fortplayer_manager = false

    for (FoundObject : InDevice.FindCreativeObjectsWithTag(fortplayer_manager_tag{})):
        if (ValidTypedObject := lego_fortplayer_manager[FoundObject]):
            set OutObject = option{ValidTypedObject}

    if (not OutObject?):
        Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("lego_fortplayer_manager not found! Make sure it is in the level and has the fortplayer_manager_tag applied.", ?Level := log_level.Warning)

    OutObject?


fortplayer_manager_log<public> := class(lego_utilities_log):
fortplayer_manager_tag<public> := class(lego_utilities_tag){} # --- MUST ASSIGN Tag: Tag_lego_fortplayer_manager to the device instance in the level! ---


# ============================================================================================================================================
# Device
# ============================================================================================================================================
lego_fortplayer_manager_fndevice_interface<public> := class<concrete>:
    @editable
    Trigger_OnLEGOFortPlayerAdded : ?trigger_device = false
    @editable
    Trigger_ClearPersistentDataForPlayer : ?trigger_device = false


lego_fortplayer_manager<public> := class(creative_device):
    @editable
    DelayBeforeAddingPlayers<protected> : float = 2.0 # NOTE: Delaying the Initialization of the LEGO player here as OnBegin is inconsistent across devices.
    @editable
    FNEventBindingInterface : lego_fortplayer_manager_fndevice_interface = lego_fortplayer_manager_fndevice_interface{}

    var ActiveLEGOPlayers<protected> : []lego_fortplayer = array{}
    Logger<protected>: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}

    OnBegin<override>()<suspends> : void =
        Logger.Print("--------------------------------------------------------------------")
        Logger.Print("lego_fortplayer_manager initialization started")
        Logger.Print("--------------------------------------------------------------------")
        GetPlayspace().PlayerRemovedEvent().Subscribe(RemovePlayerAsLEGOFortPlayer)

        if (ValidTrigger := FNEventBindingInterface.Trigger_ClearPersistentDataForPlayer?):
            ValidTrigger.TriggeredEvent.Subscribe(ClearPersistentDataForPlayer)

        Sleep(DelayBeforeAddingPlayers)
        AddInitialPlayersAsLEGOFortPlayers()
        GetPlayspace().PlayerAddedEvent().Subscribe(AddPlayerAsLEGOFortPlayer)

        Sleep(0.5) # This is to ensure OnBegin() is finished before signaling OnInitializedPlayers
        OnInitializedPlayers.Signal()
        Logger.Print("--------------------------------------------------------------------")
        Logger.Print("lego_fortplayer_manager initialization finished")
        Logger.Print("--------------------------------------------------------------------")

        Sleep(1.0)
        FoundDevices := FindCreativeObjectsWithTag(fortplayer_manager_tag{})


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Helpers
    # --------------------------------------------------------------------------------------------------------------------------------------------
    GetLEGOFortPlayerFromAgent<public>(InAgent : agent)<decides><transacts> : lego_fortplayer =
        var OutPlayer : ?lego_fortplayer = false
        if (InPlayer := player[InAgent]):
            for (Index -> LEGOPlayer: ActiveLEGOPlayers):
                if:
                    Player := LEGOPlayer.FortPlayer?
                    Player = InPlayer
                then:
                    set OutPlayer = option{LEGOPlayer}
        else:
            Logger.Print("GetLEGOFortPlayerFromAgent failed: InAgent is not a player.", ?Level := log_level.Warning)

        OutPlayer?

    GetAllLEGOFortPlayers<public>()<transacts> : []lego_fortplayer =
        ActiveLEGOPlayers

    GetPlayerTeam(InAgent : agent)<transacts> : int =
        TeamCollection := GetPlayspace().GetTeamCollection()
        if (AgentsTeam := TeamCollection.GetTeam[InAgent]):
            TeamArray := TeamCollection.GetTeams()
            for (TeamIndex -> Team : TeamArray, AgentsTeam = Team):
                Logger.Print("GetPlayerTeam - Team {TeamIndex + 1}.")
                TeamIndex + 1

        Logger.Print("GetPlayerTeam - Failed to find team for new player.", ?Level := log_level.Warning)
        return -1

    ClearPersistentDataForPlayer<public>(InAgent : ?agent) : void =
        if:
            ValidAgent := InAgent?
            ValidAgent.SetLEGOFortPlayerPersistenceData[Self, lego_fortplayer_persistence_data{}]
        then:
            Logger.Print("Cleared persistent data for player.", ?Level := log_level.Warning)
        else:
            Logger.Print("ClearPersistentDataForPlayer failed - No LEGOFortPlayer found for agent.", ?Level := log_level.Error)

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Internal
    # --------------------------------------------------------------------------------------------------------------------------------------------
    OnInitializedPlayers<public>: event() = event(){}
    AddInitialPlayersAsLEGOFortPlayers<private>()<suspends> : void =
        AllPlayers : []player = GetPlayspace().GetPlayers()
        for (FoundPlayer : AllPlayers):
            AddPlayerAsLEGOFortPlayer(FoundPlayer)
            Sleep(0.5)

    OnNewLEGOFortplayerAdded<public>: event(lego_fortplayer) = event(lego_fortplayer){}
    AddPlayerAsLEGOFortPlayer<private>(InPlayer : player) : void =
        Logger.Print("--------------------------------------------------------------------")
        Logger.Print("Player joined: creating up LEGOFortplayer.")
        if (GetLEGOFortPlayerFromAgent[InPlayer]):
            return

        # UUID to identify the player after the Agent has left the session
        var UUID : int = GetRandomInt(-2147483648, 2147483647)

        # Ensure player UUID stays consistent throughout playsessions
        if (PersistentData := GlobalPersistentData_LEGOFortPlayerData[InPlayer]):
            set UUID = PersistentData.UUID
            Logger.Print("Found existing entry for LEGOFortplayer {UUID}.")
        else:
            if (set GlobalPersistentData_LEGOFortPlayerData[InPlayer] = lego_fortplayer_persistence_data{UUID := UUID}):
                Logger.Print("Created new entry for LEGOFortplayer {UUID}.")
            else:
                Logger.Print("Failed to create new entry for LEGOFortplayer {UUID}.", ?Level := log_level.Error)

        NewLEGOFortPlayer := MakeLEGOFortPlayer(InPlayer, UUID)
        set ActiveLEGOPlayers += array{NewLEGOFortPlayer}

        spawn{NewLEGOFortPlayer.Init_LEGOFortplayer()}
        OnNewLEGOFortplayerAdded.Signal(NewLEGOFortPlayer)
        if (ValidTrigger := FNEventBindingInterface.Trigger_OnLEGOFortPlayerAdded?):
            ValidTrigger.Trigger(InPlayer)

        Logger.Print("Player joined: Added LEGOFortplayer {UUID}.")
        Logger.Print("--------------------------------------------------------------------")

    RemovePlayerAsLEGOFortPlayer<protected>(InPlayer : player) : void =
        if (LeavingLEGOPlayer := GetLEGOFortPlayerFromAgent[InPlayer]):
            ActiveLEGOPlayers.RemoveAllElements(LeavingLEGOPlayer)

            for (ActiveLEGOPlayer : ActiveLEGOPlayers):
                if (LeavingLEGOPlayer = ActiveLEGOPlayer):
                    if (ActiveLEGOPlayers.RemoveFirstElement[ActiveLEGOPlayer]){}
                    spawn{ActiveLEGOPlayer.UnInit_LEGOFortplayer()}
                    Logger.Print("Player left: Removed LEGOFortplayer {LeavingLEGOPlayer.UUID}.")
                    return

    # Override this in a child class to use a custom lego_fortplayer class.
    MakeLEGOFortPlayer<protected>(InPlayer : player, InUUID : int) : lego_fortplayer = 
        if (ValidFortChar := InPlayer.GetFortCharacter[]):
            return lego_fortplayer {FortPlayer := option{InPlayer}, FortChar := option{ValidFortChar}, UUID := InUUID}
        else:
            Logger.Print("MakeLEGOFortPlayer failed - No FortCharacter found for player.", ?Level := log_level.Error)
            return lego_fortplayer {FortPlayer := option{InPlayer}, FortChar := false}
