using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /UnrealEngine.com/Temporary/Diagnostics }

using { LEGOUtilities }

# ============================================================================================================================================
# This system is used to assign a player to a specific area. It will also assist with the loading and unloading of persistent data for the player.
# ============================================================================================================================================

(InLEGOPlayer : lego_fortplayer).RequestAreaAssignment(InDevice : creative_device)<suspends> : logic =
    for (FoundObject : InDevice.FindCreativeObjectsWithTag(lego_assignable_player_area_tag{})):
        if:
            ValidArea := lego_assignable_player_area[FoundObject]
            ValidArea.CanAssignPlayer[InLEGOPlayer]
        then:
            ValidArea.AssignPlayer(InLEGOPlayer)
            return true
    Logger: log = log{Channel := lego_assignable_player_area_log, DefaultLevel := log_level.Normal}
    Logger.Print("Failed to assign player to area - no available lego_assignable_player_area found.", ?Level := log_level.Error)
    return false

(InLEGOPlayer : lego_fortplayer).RequestAreaUnassignment(InDevice : creative_device)<suspends> : logic =
    Logger : log = log{Channel := lego_assignable_player_area_log, DefaultLevel := log_level.Normal}
    for (FoundObject : InDevice.FindCreativeObjectsWithTag(lego_assignable_player_area_tag{})):
        if:
            ValidArea := lego_assignable_player_area[FoundObject]
            ValidArea.IsPlayerAssigned[InLEGOPlayer]
        then:
            ValidArea.UnassignPlayer(InLEGOPlayer)
            Logger.Print("Unassigned player from area {ValidArea.AreaID}")
            return true
    return false

(InLEGOPlayer : lego_fortplayer).GetAssignedArea(InDevice : creative_device)<transacts><decides> : lego_assignable_player_area =
    var OutObject : ?lego_assignable_player_area = false
    for (FoundObject : InDevice.FindCreativeObjectsWithTag(lego_assignable_player_area_tag{})):
        if:
            ValidArea := lego_assignable_player_area[FoundObject]
            ValidArea.IsPlayerAssigned[InLEGOPlayer]
        then:
            set OutObject = option{ValidArea}
    return OutObject?


Tooltip_AssignableArea_ID<public><localizes> : message = "The ID of the area. Used to identify the area in the system - corresponds to Team Index."
Tooltip_AssignableArea_TeleportPlayerOnAssign<public><localizes> : message = "Should the player be teleported to the area when assigned?"
Tooltip_Teleporter<public><localizes> : message = "The teleporter device that will teleport the player to the area."
Tooltip_CinematicSequence_CameraFade<public><localizes> : message = "The cinematic sequence device that will fade the camera until the player is teleported."

Tooltip_AssignableArea_OnPlayerAssigned<public><localizes> : message = "Triggered when a player is assigned to this area."
Tooltip_Trigger_OnPlayerUnassigned<public><localizes> : message = "Triggered when a player is unassigned from this area."
Tooltip_Button_ManuallyAssignPlayer<public><localizes> : message = "Manually assign a player to this area"
Tooltip_Button_ManuallyUnssignPlayer<public><localizes> : message = "Manually unassign a player from this area"
Tooltip_AssignableArea_PlacementVolume<public><localizes> : message = "Manually unassign a player from this area"

lego_assignable_player_area_fndevice_interface<public> := class<concrete>:    
    @editable:
        ToolTip := Tooltip_AssignableArea_OnPlayerAssigned
    Trigger_OnPlayerAssigned : trigger_device = trigger_device{}

    @editable:
        ToolTip := Tooltip_Trigger_OnPlayerUnassigned
    Trigger_OnPlayerUnassigned : trigger_device = trigger_device{}

    @editable:
        ToolTip := Tooltip_Button_ManuallyAssignPlayer
    Button_ManuallyAssignPlayer : button_device = button_device{}

    @editable:
        ToolTip := Tooltip_Button_ManuallyUnssignPlayer
    Button_ManuallyUnassignPlayer : button_device = button_device{}

lego_assignable_player_area_log<public> := class(log_channel):
lego_assignable_player_area_tag<public> := class(tag){} # --- MUST ASSIGN Tag: 'Tag_lego_fortplayer_manager' to the device instance in the level! ---


# ============================================================================================================================================
# Area associated with a player, will also handle persistent data loading, unloading and applies the offset to the grid_origin that is saved
# ============================================================================================================================================

lego_assignable_player_area := class(creative_device):
    @editable:
        ToolTip := Tooltip_AssignableArea_ID
    AreaID : int = 0

    @editable:
        ToolTip := Tooltip_AssignableArea_TeleportPlayerOnAssign
    TeleportPlayerOnAssign : logic = true

    @editable:
        ToolTip := Tooltip_Teleporter
    Teleporter : teleporter_device = teleporter_device{}

    @editable:
        ToolTip := Tooltip_FNBindingsInterface
    FNBindingsInterface : ?lego_assignable_player_area_fndevice_interface = false

    @editable:
    AssignableBuildZone : lego_grid_build_zone = lego_grid_build_zone{}

    var AssignedPlayer : ?lego_fortplayer = false
    Logger<protected> : log = log{Channel := lego_assignable_player_area_log, DefaultLevel := log_level.Normal}

    OnBegin<override>()<suspends> : void =
        AssignableBuildZone.Initialize()

        if (ValidFNBindingsInterface := FNBindingsInterface?):
            ValidFNBindingsInterface.Button_ManuallyAssignPlayer.InteractedWithEvent.Subscribe(RequestAssignAgent)
            ValidFNBindingsInterface.Button_ManuallyUnassignPlayer.InteractedWithEvent.Subscribe(RequestUnassignAgent)

    # Can this player be assigned to this area (iE. is it free)?
    CanAssignPlayer(InLEGOPlayer : lego_fortplayer)<transacts><decides> : void =
        var Result : logic = false
        Logger.Print("CanAssignPlayer to Area {AreaID} - Team {InLEGOPlayer.GetTeam()}")
        
        if (AreaID = InLEGOPlayer.GetTeam()):
            set Result = true

        if (not Result?):
            if (AssignedPlayer?):
                Logger.Print("CanAssignPlayer to Area {AreaID} - Team {InLEGOPlayer.GetTeam()} - Assigned another Player already")
        Result?
    
    # Is this player assigned to this area?
    IsPlayerAssigned(InLEGOPlayer : lego_fortplayer)<transacts><decides> : void =
        var Result : logic = false
        if (AssignedPlayer? = InLEGOPlayer):
            set Result = true
        Result?

    # Assign the player to that area and load the persistent data
    AssignPlayer<public>(InLEGOPlayer : lego_fortplayer)<suspends> : void =
        if (ValidAssignedPlayer := AssignedPlayer?):
            InLEGOPlayer.RequestAreaUnassignment(Self)

        # See if this player is currently assigned to another area, unassign if so
        InLEGOPlayer.RequestAreaUnassignment(Self)
        Sleep(0.5)

        set AssignedPlayer = option{InLEGOPlayer}

        if:
            ValidPlayerAgent := InLEGOPlayer.FortPlayer?
            ValidFNBindingsInterface := FNBindingsInterface?
        then:
            ValidFNBindingsInterface.Trigger_OnPlayerAssigned.Trigger(ValidPlayerAgent)

        if:
            TeleportPlayerOnAssign?
            ValidCharacter := InLEGOPlayer.FortPlayer?.GetFortCharacter[]
            ValidCharacter.TeleportTo[Teleporter.GetTransform().Translation, Teleporter.GetTransform().Rotation]
        then:
            Logger.Print("Teleported player {InLEGOPlayer.UUID} to area {AreaID}")

        # Load the persistent data for this player and spawn all the plots and objects
        if:
            ValidGridDevice := GetLEGOGridDevice[Self]
            PlayerPersistenceData := InLEGOPlayer.FortPlayer?.GetLEGOFortPlayerPersistenceData[Self]
        then:
            ValidGridDevice.Persistence.LoadAndApply(InLEGOPlayer, PlayerPersistenceData)
        else:
            Logger.Print("ERROR - AssignPlayer failed: player persistent data load error.", ?Level := log_level.Error)

        if (Gridplayer := lego_fortplayer_grid[InLEGOPlayer]):
            set Gridplayer.AssignedBuildZone = option{AssignableBuildZone}

        Logger.Print("Assigned player {InLEGOPlayer.UUID} in team {InLEGOPlayer.GetTeam()} to Area {AreaID}")

    # Unassign the player from this area and unload all data
    UnassignPlayer<public>(InLEGOPlayer : lego_fortplayer)<suspends> : void =
        if (ValidGridDevice := GetLEGOGridDevice[Self]):
            ValidGridDevice.Persistence.UnloadPlayerData(InLEGOPlayer, ValidGridDevice)
        else:
            Logger.Print("ERROR - UnassignPlayer failed: player persistent data unload error.", ?Level := log_level.Error)

        set AssignedPlayer = false

        if:
            ValidPlayerAgent := InLEGOPlayer.FortPlayer?
            ValidFNBindingsInterface := FNBindingsInterface?
        then:
            ValidFNBindingsInterface.Trigger_OnPlayerUnassigned.Trigger(ValidPlayerAgent)
        else:
            Self.DebugPrint("ERROR - Could not get player")

        Logger.Print("Unassigned player {InLEGOPlayer.UUID} from area {AreaID}")
    
    RequestAssignAgent(InAgent : agent) : void =
        if (ValidPlayer := InAgent.GetLEGOFortPlayer[Self]):
            spawn{AssignPlayer(ValidPlayer)}
        else:
            Logger.Print("ERROR - Could not get player", ?Level := log_level.Error)

    RequestUnassignAgent(InAgent : agent) : void =
        if (ValidPlayer := InAgent.GetLEGOFortPlayer[Self]):
            spawn{UnassignPlayer(ValidPlayer)}
        else:
            Logger.Print("ERROR - Could not get player", ?Level := log_level.Error)
