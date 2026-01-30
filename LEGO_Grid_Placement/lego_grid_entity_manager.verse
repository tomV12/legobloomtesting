using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors/NamedColors }

using { LEGOUtilities }

Tooltip_GridEntityManager_Definitions<public><localizes> : message = "All the grid entity definitions that can be placed in the world."
Tooltip_GridEntityManager_UnlockPacks<public><localizes> : message = "All the unlock packs that can be used to unlock grid entities."
Tooltip_GridEntityManager_DisableUnlockPacks<public><localizes> : message = "Disable the unlock packs, effectively unlocking all grid entities."

# ============================================================================================================================================
# Holds all data that defines the assets that can be placed, their type, dimensions, UI elements and whether they are unlocked in an UnlockPack via a trigger
# ============================================================================================================================================

lego_grid_entity_manager := class(creative_device):

    # Stores definitions for all assets that can be placed using the Grid Placement system
    @editable:
        ToolTip := Tooltip_GridEntityManager_Definitions
    GridEntityDefinitions : []lego_grid_entity_definition = array{}

    Condition_Default : lego_grid_condition = lego_grid_condition_default{}
    Condition_Connected : lego_grid_condition = lego_grid_condition_connected{}
    Condition_OnSoil : lego_grid_condition = lego_grid_condition_onsoil{}
    Condition_Grounded : lego_grid_condition = lego_grid_condition_grounded{}
    Condition_FarmingPlot : lego_grid_condition = lego_grid_condition_farmingplot{}
    Condition_GridCellSize : lego_grid_condition = lego_grid_condition_gridcellsize{}
    
    # Conditions to check when placing objects of a given type
    var TypeConditions : [Types][]lego_grid_condition = 
        map:

    @editable:
        ToolTip := Tooltip_GridEntityManager_DisableUnlockPacks
    DisableUnlockPacks : logic = false

    # Stores the UnlockPacks that add the assets using them to the list of assets that can be placed
    @editable:
        ToolTip := Tooltip_GridEntityManager_UnlockPacks
    UnlockPacks : []lego_grid_unlockpack = array:
        lego_grid_unlockpack{Category := en_lego_grid_unlockpack_categories.AlwaysUnlocked}, 
        lego_grid_unlockpack{Category := en_lego_grid_unlockpack_categories.Pack_01}, 
        lego_grid_unlockpack{Category := en_lego_grid_unlockpack_categories.Pack_02}, 
        lego_grid_unlockpack{Category := en_lego_grid_unlockpack_categories.Pack_03}, 
        lego_grid_unlockpack{Category := en_lego_grid_unlockpack_categories.Pack_04}

    # Set up Logger to print to the Output Log in the grid device channel
    Logger : log = log:
        Channel := lego_grid_device_log
        DefaultLevel := log_level.Normal

    OnBegin<override>()<suspends> : void =
        for (Index -> GridEntityDefinition : GridEntityDefinitions):
            set GridEntityDefinition.EntityID = Index
            GridEntityDefinition.Initialize()

        for (UnlockPack : UnlockPacks):
            set UnlockPack.OwningDevice = Self
            UnlockPack.Initialize()

    GetGridEntityFromIndex(Index : int)<transacts> : ?lego_grid_entity_definition =
        if (GridEntity := GridEntityDefinitions[Index]):
            return option{GridEntity}
        else:
            return false

    GetGridEntityDefinitions()<transacts> : []lego_grid_entity_definition =
            return GridEntityDefinitions

    GetGridEntyDefinitionIndex<public>(InGridEntityDefinition : lego_grid_entity_definition)<transacts> : int =
        for (Index -> GridEntityDefinition : GridEntityDefinitions; InGridEntityDefinition = GridEntityDefinition):
            return Index
        return -1

    # This sets up which conditions to check based on the Type of the object to be placed
    SetTypeConditions<public>()<transacts> : void =
        if:
            set TypeConditions[Types.Connected] = array{Condition_Connected, Condition_GridCellSize}
            set TypeConditions[Types.Default] = array{Condition_Default}
            set TypeConditions[Types.Soil] = array{Condition_Grounded}
            set TypeConditions[Types.Plant] = array{Condition_OnSoil}
            set TypeConditions[Types.Grounded] = array{Condition_Grounded}
        then:   
            Logger.Print("Conditions Passed")
