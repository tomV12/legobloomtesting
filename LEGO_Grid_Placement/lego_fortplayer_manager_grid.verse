using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

using { LEGOUtilities }


Tooltip_FortPlayer_Grid_GridDevice<public><localizes> : message = "The grid device used by the LEGO FortPlayer Grid."
Tooltip_FortPlayer_Grid_UsesAreaAssignments<public><localizes> : message = "Whether the LEGO FortPlayer Grid uses area assignments for the players."
Tooltip_FortPlayer_Grid_TriggerRequestAreaAssignment<public><localizes> : message = "The trigger device that requests area assignment for the LEGO FortPlayer Grid."

# ============================================================================================================================================
# A custom version of the lego_fortplauer_manager that uses the LEGO_fortplayer_grid class
# ============================================================================================================================================

(InAgent : agent).GetGridPlayer<public>(InDevice : creative_device)<decides><transacts> : lego_fortplayer_grid =
    var OutPlayer : ?lego_fortplayer_grid = false
    if:
        GridPlayer := lego_fortplayer_grid[InAgent.GetLEGOFortPlayer[InDevice]]
        set OutPlayer = option{GridPlayer}
    OutPlayer?

lego_fortplayer_manager_grid := class(lego_fortplayer_manager):
    @editable:
        ToolTip := Tooltip_FortPlayer_Grid_GridDevice
    GridDevice : lego_grid_device = lego_grid_device{}

    @editable:
        ToolTip := Tooltip_FortPlayer_Grid_UsesAreaAssignments
    UsesAreaAssignments : logic = false

    @editable:
        ToolTip := Tooltip_FortPlayer_Grid_TriggerRequestAreaAssignment
    Trigger_RequestAreaAssignment : trigger_device = trigger_device{}

    OnBegin<override>()<suspends>: void =
        (super:)OnBegin()
        Trigger_RequestAreaAssignment.TriggeredEvent.Subscribe(OnRequestAreaAssignment)

    OnRequestAreaAssignment(InAgent : ?agent) : void =
        if (ValidFortPlayer := InAgent?.GetGridPlayer[GridDevice]):
            spawn{ValidFortPlayer.RequestAreaAssignment(Self)}

    MakeLEGOFortPlayer<override>(InPlayer : player, InUUID : int) : lego_fortplayer_grid = 
        if (ValidFortChar := InPlayer.GetFortCharacter[]):
            OutGridPlayer := new_lego_FortPlayer_Grid(option{InPlayer}, option{ValidFortChar}, InUUID)
            set OutGridPlayer.UsesAreaAssignments = UsesAreaAssignments
            set OutGridPlayer.GridDevice = GridDevice
            return OutGridPlayer
        else:
            Logger.Print("Failed to create LEGO_fortplayer_grid - No valid FortCharacter found.", ?Level := log_level.Warning)
            return new_lego_FortPlayer_Grid(option{InPlayer}, false, -1)