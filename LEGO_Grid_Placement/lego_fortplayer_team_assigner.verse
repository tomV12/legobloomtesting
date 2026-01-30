using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /UnrealEngine.com/Temporary/Diagnostics }

using { LEGOUtilities }

Tooltip_FortPlayerTeams_Index<public><localizes> : message = "The index of the team, used to identify the team in the system."
Tooltip_FortPlayerTeams_Assigner<public><localizes> : message = "The device that assigns the team to the player."
Tooltip_FortPlayerTeams_MaxSize<public><localizes> : message = "The maximum number of players that can be assigned to this team."
Tooltip_FortPlayerTeams_Trigger<public><localizes> : message = "Trigger device to trigger when a player is assigned to this team."
Tooltip_FortPlayerTeams_Teams<public><localizes> : message = "The teams that players can be assigned to."

# ============================================================================================================================================
# This manually assigns/unassigns players to teams based on a simple team-balancing mechanism
# ============================================================================================================================================
GetTeamAssigner<public>(InDevice : creative_device)<decides><transacts> : lego_fortplayer_team_assigner =
    var OutObject : ?lego_fortplayer_team_assigner = false

    for (FoundObject : InDevice.FindCreativeObjectsWithTag(team_assigner_tag{})):
        if (ValidTypedObject := lego_fortplayer_team_assigner[FoundObject]):
            set OutObject = option{ValidTypedObject}
      
    if (not OutObject?):
        Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("lego_fortplayer_team_assigner not found! Make sure it is in the level and has the team_assigner_tag applied.", ?Level := log_level.Warning)
        
    OutObject?


# Team Definition 
lego_fortplayer_team_definition := class<concrete>:
    @editable:
        ToolTip := Tooltip_FortPlayerTeams_Index
    TeamIndex : int = -1

    @editable:
        ToolTip := Tooltip_FortPlayerTeams_Assigner
    ClassAndTeamSelector : class_and_team_selector_device = class_and_team_selector_device{}

    @editable:
        ToolTip := Tooltip_FortPlayerTeams_MaxSize
    MaxSize : int = 1

    @editable:
        ToolTip := Tooltip_FortPlayerTeams_Trigger
    Trigger_AssignToTeam : trigger_device = trigger_device{}

    var CurrentSize : int = 0
    var OwningDevice : creative_device = creative_device{}

    Initialize<public>(InOwningDevice : creative_device): void=
        set OwningDevice = InOwningDevice
        Trigger_AssignToTeam.TriggeredEvent.Subscribe(RequestTeamAssign)

    RequestTeamAssign<protected>(InAgent : ?agent): void=
        if (ValidFortPlayer := InAgent?.GetLEGOFortPlayer[OwningDevice]):
            AssignToTeam(ValidFortPlayer)

    CanAssignToTeam<public>()<transacts><decides> : void =
        var Result : logic = false
        if (CurrentSize < MaxSize):
            set Result = true
        Result?

    AssignToTeam<public>(InLEGOFortPlayer : lego_fortplayer) : void =
        set CurrentSize += 1
        InLEGOFortPlayer.SetTeam(TeamIndex)
        if (ValidAgent := InLEGOFortPlayer.FortPlayer?) {ClassAndTeamSelector.ChangeTeamAndClass(ValidAgent)}
        Logger : log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("Assigned to team {TeamIndex} - Player {InLEGOFortPlayer.UUID}")

    RemoveFromTeam<public>(InLEGOFortPlayer : lego_fortplayer) : void =
        set CurrentSize -= 1
        if (CurrentSize < 0):
            set CurrentSize = 0
        Logger: log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("Removed from team {TeamIndex} - Player {InLEGOFortPlayer.UUID}")
        

# ============================================================================================================================================
# Manually manages Team Index instead of the buggy and wierd FN system using player_spawner_devices and Playspace
# ============================================================================================================================================

team_assigner_tag<public> := class(fortplayer_manager_tag){} # --- MUST ASSIGN Tag: Tag_LEGO_fortplayer_team_assigner to the device instance in the level! ---

lego_fortplayer_team_assigner<public> := class(creative_device):
    @editable:
        ToolTip := Tooltip_FortPlayerTeams_Teams
    Teams : []lego_fortplayer_team_definition = array{}

    Logger<protected> : log = log{Channel := fortplayer_manager_log, DefaultLevel := log_level.Normal}

    OnBegin<override>()<suspends>: void =
        for (Team : Teams):
            Team.Initialize(Self)

    # Player can request to be assigned to a team, returns the team index
    RequestTeam<public> (InLEGOFortPlayer : lego_fortplayer) : int =
        for (Team : Teams):
            if (Team.CanAssignToTeam[]):
                Team.AssignToTeam(InLEGOFortPlayer)
                return Team.TeamIndex
        Logger.Print("RequestTeam failed! No team available - Player {InLEGOFortPlayer.UUID}", ?Level := log_level.Error)
        return -1

    # Player can request to leave a team
    RequestLeaveTeam<public>(InLEGOFortPlayer : lego_fortplayer) : void =
        for (Team : Teams):
            if (Team.TeamIndex = InLEGOFortPlayer.GetTeam()):
                Team.RemoveFromTeam(InLEGOFortPlayer)
                Logger.Print("Removed from Team {Team.TeamIndex} Player: {InLEGOFortPlayer.UUID}")
                return
