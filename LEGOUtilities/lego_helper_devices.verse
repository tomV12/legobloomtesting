using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /UnrealEngine.com/Temporary/Diagnostics }

# ================================================================================================================================================
# HUD Message Provider
# - Provide access to standartised HUD messages throught the project using Agent.RequestHUDMessage()
# ================================================================================================================================================
RequestHUDMessage<public>(InDevice : creative_device, InText : string, InAgent : agent, ?InTypeIndex : int = 0) : void =
    TaggedObjects := InDevice.FindCreativeObjectsWithTag(hud_message_provider_tag{})

    for (TaggedObject : TaggedObjects, ValidTypedObject := LEGO_hud_message_provider[TaggedObject]):
        ValidTypedObject.RequestHUDMessageByType(InText, InAgent, ?InTypeIndex := InTypeIndex)
        return

    Logger : log = log{Channel := hud_message_provider_log, DefaultLevel := log_level.Warning}
    Logger.Print("RequestHUDMessage failed: No HUD message provider found.")

hud_message_provider_tag<public> := class(lego_utilities_tag): # --- MUST ASSIGN Tag to the device instance in the level! ---
hud_message_provider_log<public> := class(lego_utilities_log):

LEGO_hud_message_provider := class(creative_device):
    @editable
    HUDMessages_Notification : []hud_message_device = array{}

    RequestHUDMessageByType<public>(InText : string, InAgent : agent, ?InTypeIndex : int = 0) : void =
        if (ValidDevice := HUDMessages_Notification[InTypeIndex]):
            ValidDevice.SetText(StringToMessage(InText))
            ValidDevice.Show(InAgent)


# ================================================================================================================================================
# XP Granter Device
# - Allows for simple access to accolades devices using Agent.GrantXP()
# - Optionally filter the accolades device by an identifier (Accolades have a Name field that shows up on the creator portal statistics)
# ================================================================================================================================================
(InAgent : agent).GrantXP<public>(InDevice : creative_device, InAmount : EN_XP_Amount, ?InFilter : string = ""): void =
    TaggedObjects := InDevice.FindCreativeObjectsWithTag(xp_granter_tag{})

    for (TaggedObject : TaggedObjects, ValidTypedObject := lego_xp_granter_device[TaggedObject]):
        ValidTypedObject.GrantXPToPlayer(InAgent, InAmount, ?InFilter := InFilter)
        return

    Logger: log = log{Channel := xp_granter_log, DefaultLevel := log_level.Normal}
    Logger.Print("xp_granter not found! Make sure it is in the level and has the Tag_LEGO_XPGranter applied.", ?Level := log_level.Warning)
        

EN_XP_Amount<public> := enum{VerySmall, Small, Medium, Large, VeryLarge} 
xp_granter_tag := class(lego_utilities_tag){}
xp_granter_log<public> := class(lego_utilities_log){}

# Some devices may have an optional identifier to filter the XP granter
lego_xp_granter_reference := class<concrete>:
    @editable
    AccoladesDevice : accolades_device = accolades_device{}
    @editable
    OptionalFilterID : ?string = false

lego_xp_granter_device := class(creative_device):
    @editable
    Accolades_VerySmall : []lego_xp_granter_reference = array{}
    @editable
    Accolades_Small : []lego_xp_granter_reference = array{}
    @editable
    Accolades_Medium : []lego_xp_granter_reference = array{}
    @editable
    Accolades_Large : []lego_xp_granter_reference = array{}
    @editable
    Accolades_VeryLarge : []lego_xp_granter_reference = array{}
    
    Logger: log = log{Channel := hud_message_provider_log, DefaultLevel := log_level.Normal}

    GrantXPToPlayer<public>(InAgent : agent, InAmount : EN_XP_Amount, ?InFilter : string = "") : void =
        case (InAmount):
            EN_XP_Amount.VerySmall =>
                if (ValidDevice := Accolades_VerySmall.FilterByIdentifier[InFilter]):
                    ValidDevice.Award(InAgent)
            EN_XP_Amount.Small =>
                if (ValidDevice := Accolades_Small.FilterByIdentifier[InFilter]):
                    ValidDevice.Award(InAgent)
            EN_XP_Amount.Medium =>
                if (ValidDevice := Accolades_Medium.FilterByIdentifier[InFilter]):
                    ValidDevice.Award(InAgent)
            EN_XP_Amount.Large =>
                if (ValidDevice := Accolades_Large.FilterByIdentifier[InFilter]):
                    ValidDevice.Award(InAgent)
            EN_XP_Amount.VeryLarge =>
                if (ValidDevice := Accolades_VeryLarge.FilterByIdentifier[InFilter]):
                    ValidDevice.Award(InAgent)

    (InReferences : []lego_xp_granter_reference).FilterByIdentifier(InIdentifier : string)<transacts><decides>: accolades_device =
        var FilteredAccolades : ?accolades_device = false
        if (InIdentifier.Length = 0):
            set FilteredAccolades = option{InReferences[0].AccoladesDevice}
        else:
            for (Reference : InReferences, Reference.OptionalFilterID = InIdentifier):
                set FilteredAccolades = option{Reference.AccoladesDevice}
        FilteredAccolades?