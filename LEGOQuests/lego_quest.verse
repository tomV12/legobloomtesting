using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { LEGOUtilities }

Tooltip_QName<public><localizes> : message = "The name of the quest as it will appear in the tracker_device and dialog UI. MUST be unique!"
ToolTip_EventBindings<public><localizes> : message = "Trigger Devices for linking other Fortnite Creative devices to this quest."
Tooltip_Tracker<public><localizes> : message = "The tracker_device that is required to complete for finishing the quest."
Tooltip_Beacon<public><localizes> : message = "This beacon can be used to guide the player towards the objective of the quest."
Tooltip_ObjectiveDescription<public><localizes> : message = "The description as visible in the tracker_device UI."
Tooltip_DialogText_Start<public><localizes> : message = "The text that will be displayed in the dialog when the quest is started."
Tooltip_DialogText_Complete<public><localizes> : message = "The text that will be displayed in the dialog when the quest is completed."

# ============================================================================================================================================
# Definition of a completable quest with dialog setup and reward
# ============================================================================================================================================
en_lego_quest_progress<public> := enum:
    None, 
    NotStarted, 
    IsActive, 
    CanBeCompleted, 
    Completed

lego_quest_log<public> := class(log_channel) {}

lego_quest_repeatable<public> := class<concrete><unique>(lego_quest) {}
lego_quest<public> := class<concrete><unique>():
    @editable:
        ToolTip := Tooltip_QName
    Name<public> : string = "UNIQUE Quest Name"

    @editable
    DisplayText<public> : lego_quest_info = lego_quest_info{}

    @editable:
        ToolTip := ToolTip_EventBindings
    EventBindings<public> : ?lego_quest_eventbindings = false
    
    @editable:
        ToolTip := Tooltip_Tracker
    TrackerDevice<public> : tracker_device = tracker_device{}
    
    @editable:
        ToolTip := Tooltip_Beacon
    GuidingBeacons<public> : []beacon_device = array{}

    var CompletedObjectives : [agent]logic = map{}
    var TrackerDeviceQuestGiver : tracker_device = tracker_device{}
    var ReturnBeacon : beacon_device = beacon_device{}
    var RestrictedToTeam : ?int = false
    Logger<protected> : log = log{Channel := lego_quest_log, DefaultLevel := log_level.Normal}

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # API
    # --------------------------------------------------------------------------------------------------------------------------------------------
    # This is called by the quest giver to setup the quest with the required devices
    Setup<public>(InCreativeDevice : creative_device, InTrackerDeviceQuestGiver : tracker_device, InReturnBeacon : beacon_device, InRestrictToTeamID : ?int) : void =
        set TrackerDeviceQuestGiver = InTrackerDeviceQuestGiver
        set ReturnBeacon = InReturnBeacon
        set RestrictedToTeam = InRestrictToTeamID
        TrackerDevice.CompleteEvent.Subscribe(OnCompletedObjective)            
        TrackerDevice.SetTitleText(ToMessage(Name))
        TrackerDevice.SetDescriptionText(ToMessage(DisplayText.Description))

    # Start the quest for a player, add it to the quest log and update the tracker device
    StartQuest<public>(InAgent : agent) : void =
        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            TrackerDevice.Reset(InAgent)
            TrackerDevice.Assign(InAgent)
        
            for (Beacon : GuidingBeacons):
                Beacon.AddToShowList(InAgent)

            if (ValidTrigger := EventBindings?.Trigger_OnStartedQuest?):
                ValidTrigger.Trigger(InAgent)
            
            # Update persistent quest log
            UpdatedQuestLog := lego_persistent_quest_log:
                ActiveQuests := ValidQuestLog.ActiveQuests + array{Name},
                CompletedQuests := ValidQuestLog.CompletedQuests

            if (InAgent.SaveLegoQuestLog[UpdatedQuestLog]):
                Logger.Print("Quest Log updated.")
        else:
            Logger.Print("StartQuest failed - no quest log found.", ?Level := log_level.Error)

    PauseQuest<public>(InAgent : agent) : void =
        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            TrackerDevice.Remove(InAgent)

            for (Beacon : GuidingBeacons):
                Beacon.RemoveFromShowList(InAgent)

            ReturnBeacon.RemoveFromShowList(InAgent)
            TrackerDeviceQuestGiver.Remove(InAgent)
    
    # Resume the quest for a player, add it to the quest log and update the tracker device
    ResumeQuest<public>(InAgent : agent) : void =
        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            TrackerDevice.Assign(InAgent)
        
            for (Beacon : GuidingBeacons):
                Beacon.AddToShowList(InAgent)

            if (ValidTrigger := EventBindings?.Trigger_OnStartedQuest?):
                ValidTrigger.Trigger(InAgent)
        else:
            Logger.Print("StartQuest failed - no quest log found.", ?Level := log_level.Error)

    # Abort the quest for a player, remove it from the quest log and update the tracker device
    AbortQuest<public>(InAgent : agent) : void =
        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            TrackerDevice.Reset(InAgent)
            TrackerDevice.Remove(InAgent)

            for (Beacon : GuidingBeacons):
                Beacon.RemoveFromShowList(InAgent)

            if (ValidTrigger := EventBindings?.Trigger_OnAbortedQuest?):
                ValidTrigger.Trigger(InAgent)

            TrackerDeviceQuestGiver.Remove(InAgent)

            # Update persistent quest log
            var UpdatedActiveQuests : []string = array{}

            for (ActiveQuest : ValidQuestLog.ActiveQuests; ActiveQuest <> Name):
                set UpdatedActiveQuests += array{ActiveQuest}

            UpdatedQuestLog := lego_persistent_quest_log:
                ActiveQuests := UpdatedActiveQuests
                CompletedQuests := ValidQuestLog.CompletedQuests

            if (InAgent.SaveLegoQuestLog[UpdatedQuestLog]) {}
        else:
            Logger.Print("AbortQuest failed - no quest log found.", ?Level := log_level.Error)

    # Complete the quest for a player, remove it from the quest log and update the tracker device, handle rewards
    CompleteQuest<public>(InAgent : agent) : void =
        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            TrackerDevice.Complete(InAgent)
            TrackerDevice.Remove(InAgent)
            ReturnBeacon.RemoveFromShowList(InAgent)

            if (lego_quest_repeatable[Self]):
                TrackerDevice.Reset(InAgent)

            for (Beacon : GuidingBeacons):
                Beacon.RemoveFromShowList(InAgent)

            if (ValidTrigger := EventBindings?.Trigger_OnCompletedQuest?):
                ValidTrigger.Trigger(InAgent)

            TrackerDeviceQuestGiver.Remove(InAgent)

            # Update persistent quest log
            var UpdatedActiveQuests : []string = array{}

            for (ActiveQuest : ValidQuestLog.ActiveQuests; ActiveQuest <> Name):
                set UpdatedActiveQuests += array{ActiveQuest}
                
            UpdatedQuestLog := lego_persistent_quest_log:
                ActiveQuests := UpdatedActiveQuests
                CompletedQuests := ValidQuestLog.CompletedQuests + array{Name}

            if (InAgent.SaveLegoQuestLog[UpdatedQuestLog]) {}
        else:
            Logger.Print("CompleteQuest failed - no quest log found.", ?Level := log_level.Error)

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Helper functions to determine the state of the quest
    # --------------------------------------------------------------------------------------------------------------------------------------------
    IsActive<public>(InAgent : agent)<transacts><decides> : void =
        var Result : logic = false

        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            if (ValidQuestLog.ActiveQuests.Find[Name]):
                set Result = true
        Result?

    CanBeStarted<public>(InAgent : agent)<transacts><decides> : void =
        var Result : logic = true

        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            if (ValidQuestLog.ActiveQuests.Find[Name]):
                set Result = false

            if (ValidQuestLog.CompletedQuests.Find[Name]):
                if (not lego_quest_repeatable[Self]):
                    set Result = false
        else:
            Logger.Print("No quest log found for agent.")
            set Result = false

        Result?
        
    CanBeCompleted<public>(InAgent : agent)<transacts><decides> : void =
        var Result : logic = false

        if (CompletedObjectives[InAgent] = true):
            set Result = true

        Result?

    HasBeenCompleted<public>(InAgent : agent)<transacts><decides> : void =
        var Result : logic = false

        if (ValidQuestLog := InAgent.LoadLegoQuestLog[]):
            if (ValidQuestLog.CompletedQuests.Find[Name]):
                set Result = true
    
        Result?
    
    OnCompletedObjective<public>(InAgent : agent) : void =
        if (set CompletedObjectives[InAgent] = true) {}        
        TrackerDeviceQuestGiver.Assign(InAgent)
        
        for (Beacon : GuidingBeacons):
                Beacon.RemoveFromShowList(InAgent)
        
        if (RestrictedToTeam?):
            if (InAgent.GetLEGOFortPlayer[creative_device{}].GetTeam() = RestrictedToTeam?):
                ReturnBeacon.AddToShowList(InAgent)
        else:
            ReturnBeacon.AddToShowList(InAgent)
        
# --------------------------------------------------------------------------------------------------------------------------------------------
# Quest Info class, used to pass the quest description and dialog texts to the dialog UI
# --------------------------------------------------------------------------------------------------------------------------------------------
lego_quest_info<public> := class<concrete>:
    @editable:
        ToolTip := Tooltip_ObjectiveDescription
    Description<public> : string = "Quest description"

    @editable_text_box:
        ToolTip := Tooltip_DialogText_Start
        MultiLine := true
    DialogText_Start<public> : string = ""
    
    @editable_text_box:
        ToolTip := Tooltip_DialogText_Complete
        MultiLine := true
    DialogText_Complete<public> : string = ""
        
# ============================================================================================================================================
# Event binding interface
# ============================================================================================================================================
lego_quest_eventbindings<public> := class<concrete>:
    @editable
    Trigger_OnStartedQuest : ?trigger_device = false
    @editable
    Trigger_OnAbortedQuest : ?trigger_device = false
    @editable
    Trigger_OnCompletedQuest : ?trigger_device = false
