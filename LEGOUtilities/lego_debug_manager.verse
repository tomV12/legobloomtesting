using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }

# ============================================================================================================================================
# Easy and clean debugging :)
# ============================================================================================================================================

# Print a debug message to the log and screen
DebugLog<public>(InString : string, ?Level : log_level = log_level.Normal)<transacts> : void =
    Logger : log = log{Channel := debug_manager_log}
    Logger.Print(InString, ?Level := Level)

# Print a debug message to the log only when DebugMode is enabled
DebugPrint<public>(InString : string, ?Duration : float = 5.0, ?Color : color = NamedColors.Green, ?PrintToLog : logic = true)<transacts> : void =
    if (PrintToLog?):
        DebugLog(InString)

# Print a debug message to the log only when DebugMode is enabled
(InDevice : creative_device).DebugPrint<public>(InString : string, ?Duration : float = 5.0, ?Color : color = NamedColors.Green, ?PrintToLog : logic = true)<transacts> : void =
    if (IsDebugModeEnabled(InDevice)?):
        Print(InString, ?Duration := Duration, ?Color := Color)
    if (PrintToLog?):
        DebugLog(InString)

IsDebugModeEnabled<public>(InDevice : creative_device)<transacts> : logic =
    if (DebugManager := InDevice.GetDebugManager[]):
        return DebugManager.IsDebugModeState()
    return false

(InDevice : creative_device).GetDebugManager<public>()<decides><transacts> : lego_debug_manager_device =
    var OutObject : ?lego_debug_manager_device = false
    ObjectsWithTag := InDevice.FindCreativeObjectsWithTag(debug_manager_tag{})

    for (ObjectWithTag : ObjectsWithTag, ValidTypedObject := lego_debug_manager_device[ObjectWithTag]):
        set OutObject = option{ValidTypedObject}

    if (not OutObject?):
        Logger: log = log{Channel := debug_manager_log, DefaultLevel := log_level.Normal}
        Logger.Print("utility_debug_manager not found! Make sure it is in the level and has the Tag_DebugManager applied.", ?Level := log_level.Warning) 
    OutObject?


Tooltip_DebugManager_TriggerEnabled<public><localizes> : message = "Trigger On Debug Mode Enabled"
Tooltip_DebugManager_TriggerDisabled<public><localizes> : message = "Trigger On Debug Mode Disabled"
Tooltip_DebugManager_SetEnabled<public><localizes> : message = "Trigger Set Debug Mode Enabled"
Tooltip_DebugManager_SetDisabled<public><localizes> : message = "Trigger Set Debug Mode Disabled"

Tooltip_DebugManager_Toggle<public><localizes> : message = "Toggle Debug Mode using an input_trigger_device, enabling debug features and HUD messages"
Tooltip_DebugManager_HUDMessage<public><localizes> : message = "HUD Message to show when Debug Mode is enabled"
Tooltip_DebugManager_ClassSelectorDebug<public><localizes> : message = "Class Selector to assign when Debug Mode is enabled"
Tooltip_DebugManager_ClassSelectorNormal<public><localizes> : message = "Class Selector to assign when Debug Mode is disabled"
Tooltip_DebugManager_Teleporters<public><localizes> : message = "Teleporters to enable/disable when Debug Mode is enabled/disabled"
Tooltip_DebugManager_DebugMode<public><localizes> : message = "Initial state of Debug Mode"

# ============================================================================================================================================
# Device
# - Debug Mode (toggled by input_trigger_device)
# - EventBindings for DebugModeChanged enabling FN device enable/disable and HUDMessages
# - Assigns a class to the agent when DebugMode is enabled (to enable fly, walk speed, etc.)
# ============================================================================================================================================
debug_manager_log<public> := class(lego_utilities_log):
debug_manager_tag<public> := class(lego_utilities_tag){} # --- MUST ASSIGN Tag to the device instance in the level! ---

lego_debug_manager_fndevice_interface := class<concrete>:
    @editable:
        ToolTip := Tooltip_DebugManager_TriggerEnabled
    Trigger_OnDebugModeEnabled : trigger_device = trigger_device{}
    @editable:
        ToolTip := Tooltip_DebugManager_TriggerDisabled
    Trigger_OnDebugModeDisabled : trigger_device = trigger_device{}

    @editable:
        ToolTip := Tooltip_DebugManager_SetEnabled
    Trigger_SetDebugModeEnabled : trigger_device = trigger_device{}
    @editable:
        ToolTip := Tooltip_DebugManager_SetDisabled
    Trigger_SetDebugModDisabled : trigger_device = trigger_device{}

lego_debug_manager_device<public> := class(creative_device):
    @editable:
        ToolTip := Tooltip_DebugManager_Toggle
    InputTrigger_Toggle : ?input_trigger_device = false

    @editable:
        ToolTip := Tooltip_DebugManager_HUDMessage
    HUDMessage_ShowWhileEnabled : ?hud_message_device = false

    @editable:
        ToolTip := Tooltip_DebugManager_ClassSelectorDebug
    ClassSelector_Debug : ?class_and_team_selector_device = false
    @editable:
        ToolTip := Tooltip_DebugManager_ClassSelectorNormal
    ClassSelector_Normal : ?class_and_team_selector_device = false

    @editable:
        ToolTip := Tooltip_DebugManager_Teleporters
    Teleporters_ToDebugArea : []teleporter_device = array{}

    @editable:
        ToolTip := Tooltip_DebugManager_DebugMode
    var DebugMode<protected> : logic = true

    IsDebugModeState<public>()<transacts> : logic = 
        DebugMode
    
    @editable:
        ToolTip := Tooltip_FNBindingsInterface
    FNEventBindingInterface : ?lego_debug_manager_fndevice_interface = false

    OnBegin<override>()<suspends> : void =
        if (ValidDevice := InputTrigger_Toggle?):
            ValidDevice.PressedEvent.Subscribe(OnInputTriggerPressed)

        if (ValidDevice := HUDMessage_ShowWhileEnabled?):
            ValidDevice.SetText(StringToMessage("Testing Mode active"))
            ValidDevice.Hide()

        if (ValidFNDeviceInterface := FNEventBindingInterface?):
            ValidFNDeviceInterface.Trigger_SetDebugModeEnabled.TriggeredEvent.Subscribe(RequestDebugModeEnable)
            ValidFNDeviceInterface.Trigger_SetDebugModDisabled.TriggeredEvent.Subscribe(RequestDebugModeDisable)


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # State Management
    # --------------------------------------------------------------------------------------------------------------------------------------------
    RequestDebugModeEnable(InAgent : ?agent) : void =
        if (ValidAgent := InAgent?):
            SetDebugModeEnabled(ValidAgent, true)

    RequestDebugModeDisable(InAgent : ?agent) : void =
        if (ValidAgent := InAgent?):
            SetDebugModeEnabled(ValidAgent, false)


    OnDebugModeChanged<public> : event(logic) = event(logic){}
    SetDebugModeEnabled<public>(InAgent : agent, InValue : logic) : void =
        set DebugMode = InValue
        if (DebugMode?):
            if (ValidDevice := HUDMessage_ShowWhileEnabled?):
                ValidDevice.Show()

            if (ValidDevice := ClassSelector_Debug?):
                ValidDevice.ChangeClass(InAgent)

            for (Teleporter : Teleporters_ToDebugArea):
                Teleporter.Enable()

            if (ValidDevice := FNEventBindingInterface?.Trigger_OnDebugModeEnabled):
                ValidDevice.Trigger(InAgent)
        else:
            if (ValidDevice := HUDMessage_ShowWhileEnabled?):
                ValidDevice.Hide()

            if (ValidDevice := ClassSelector_Normal?):
                ValidDevice.ChangeClass(InAgent)

            for (Teleporter : Teleporters_ToDebugArea):
                Teleporter.Disable()

            if (ValidDevice := FNEventBindingInterface?.Trigger_OnDebugModeDisabled):
                ValidDevice.Trigger(InAgent)

        OnDebugModeChanged.Signal(DebugMode)


    OnInputTriggerPressed(InAgent : agent) : void =
        if (DebugMode?):
            Self.DebugPrint("Debug Mode Disabled", ?Duration := 2.0, ?Color := Red)
            SetDebugModeEnabled(InAgent, false)
        else:
            SetDebugModeEnabled(InAgent, true)
            Self.DebugPrint("Debug Mode Enabled", ?Duration := 2.0, ?Color := Red)
            
        OnDebugModeChanged.Signal(DebugMode)
