using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }


(InDevice : creative_device).Analytics_RequestEvent<public>(InEventID : string, InAgent : agent): void =
    TaggedObjects := InDevice.FindCreativeObjectsWithTag(analytics_provider_tag{})
    for (TaggedObject : TaggedObjects):
        if (ValidTypedObject := lego_analytics_provider[TaggedObject]):
            ValidTypedObject.ResolveEventBinding(InEventID, InAgent)
            return
    Logger : log = log{Channel := analytics_provider_log, DefaultLevel := log_level.Warning}
    Logger.Print("No analytics provider found for event ID: {InEventID}.")


# ------------------------------------------------------------------------------------------------------------------------------------
# Binding Definitions (either Verse invoked or via a trigger_device)
# ------------------------------------------------------------------------------------------------------------------------------------
utility_analytics_event_binding := class<concrete>:
    @editable
    EventID : string = ""
    @editable
    AnalyticsDevice : analytics_device = analytics_device{}

utility_analytics_trigger_binding := class<concrete>:
    @editable
    EventID : string = ""
    @editable
    TriggerDevice : trigger_device = trigger_device{}
    @editable
    AnalyticsDevice : analytics_device = analytics_device{}

    Setup<public>() : void =
        TriggerDevice.TriggeredEvent.Subscribe(OnRequestSubmission)

    OnRequestSubmission(InAgent : ?agent): void =
        if (ValidAgent := InAgent?): 
            AnalyticsDevice.Submit(ValidAgent)
            Logger : log = log{Channel := analytics_provider_log, DefaultLevel := log_level.Normal}
            Logger.Print("Submitted analytics event with ID: {EventID}.")


analytics_provider_log<public> := class(log_channel):
analytics_provider_tag<public> := class(lego_utilities_tag){} # --- MUST ASSIGN Tag to the device instance in the level! ---
# ============================================================================================================================================
# Distribute analytics event requests to a pre-defined object pool of analytics_devices
# ============================================================================================================================================
lego_analytics_provider := class(creative_device):
    # The bindings should just be maps, but @editable isn't supported for maps yet...
    @editable
    EventBindings : []utility_analytics_event_binding = array{}
    @editable
    TriggerBindings : []utility_analytics_trigger_binding = array{}

    Logger : log = log{Channel := analytics_provider_log, DefaultLevel := log_level.Normal}
    
    OnBegin<override>()<suspends> : void =
        Logger.Print("{EventBindings.Length} analytics event bindings found.")
        for (TriggerBinding : TriggerBindings):
            TriggerBinding.Setup()

    ResolveEventBinding<public>(InEventID : string, InAgent : agent) : void =
        for: 
            EventBinding : EventBindings
            EventBinding.EventID = InEventID
        do:
            EventBinding.AnalyticsDevice.Submit(InAgent)
            Logger.Print("Submitted analytics event with ID: {InEventID}.")
            return
        Logger.Print("ResolveEventBinding failed for ID: {InEventID}.", ?Level := log_level.Warning)