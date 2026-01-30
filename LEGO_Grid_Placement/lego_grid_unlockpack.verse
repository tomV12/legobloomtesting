using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/Diagnostics }

using { LEGOUtilities }

Tooltip_UnlockPack_Category<public><localizes> : message = "The category of the unlock pack."
Tooltip_UnlockPack_Triggers<public><localizes> : message = "The trigger_devices that will unlock this AssetPack for the triggering player."

# ========================================================================================================================================
# Allows the player to unlock a set of assets, essentially gating placeable content
# Saved to persistence so that the player does not have to unlock the same assets again
# ========================================================================================================================================
en_lego_grid_unlockpack_categories<public> := enum{
    AlwaysUnlocked, 
    Pack_01, 
    Pack_02, 
    Pack_03, 
    Pack_04
}

(InEnum : en_lego_grid_unlockpack_categories).ToString() : string =
    case (InEnum):
        en_lego_grid_unlockpack_categories.AlwaysUnlocked =>
            "AlwaysUnlocked"
        en_lego_grid_unlockpack_categories.Pack_01 =>
            "Pack_01"
        en_lego_grid_unlockpack_categories.Pack_02 =>    
            "Pack_02"
        en_lego_grid_unlockpack_categories.Pack_03 =>
            "Pack_03"        
        en_lego_grid_unlockpack_categories.Pack_04 =>
            "Pack_04"

lego_grid_unlockpack := class(lego_initializable_interface):
    var OwningDevice : creative_device = creative_device{}
    
    @editable:
        ToolTip := Tooltip_UnlockPack_Category
    Category : en_lego_grid_unlockpack_categories = en_lego_grid_unlockpack_categories.AlwaysUnlocked

    @editable:
        ToolTip := Tooltip_UnlockPack_Triggers
    Triggers_Unlock : []trigger_device = array{}

    Logger : log = log:
        Channel := lego_grid_device_log
        DefaultLevel := log_level.Normal

    Initialize<override>() : void =
        for (Trigger : Triggers_Unlock):
            Trigger.TriggeredEvent.Subscribe(Unlock)
        
    Unlock(InAgent : ?agent) : void =
        if (ValidFortPlayer := InAgent?.GetGridPlayer[OwningDevice]):
            GridEntityDefinitions := ValidFortPlayer.GridDevice.EntityManager.GetGridEntityDefinitions()

            for (Index -> GridEntityDefinition : GridEntityDefinitions):
                if (GridEntityDefinition.UnlockCategory = Category):
                    ValidFortPlayer.UnlockAsset(Index)
