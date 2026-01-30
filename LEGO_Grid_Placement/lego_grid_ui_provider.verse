using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Assets }
using { /Verse.org/Colors }

using { LEGOUtilities }


# ==================================================================================================
# This is associated with a lego_fortplayer and maintains a UI for the player to interact with the grid
# ==================================================================================================

lego_grid_ui_log<public> := class(log_channel) {}

lego_grid_ui_provider := class:
    var OwningPlayer : lego_fortplayer = lego_fortplayer{}
    var IsVisisble : logic = false
    var GridDevice : lego_grid_device = lego_grid_device{}
    GridUI : lego_grid_ui = lego_grid_ui{}

    Logger<protected> : log = log:
        Channel := lego_grid_ui_log
        DefaultLevel := log_level.Normal

    Initialize<public>(InLEGOPlayer : lego_fortplayer_grid) : void =
        set OwningPlayer = InLEGOPlayer

        # Get all the Object Definitions and initialize the UI with the Data
        if: 
            FoundGridDevice := InLEGOPlayer.GridDevice
            ValidPlayer := InLEGOPlayer.FortPlayer?
        then:
            set GridDevice = FoundGridDevice
            UpdateGridUI(InLEGOPlayer)
            
            # Setup Inpout Trigger bindings
            GridDevice.InputTrigger_OpenGridUI.PressedEvent.Subscribe(RequestShow)  

            if (GridFortPlayer := lego_fortplayer_grid[InLEGOPlayer]):
                spawn{Loop_Update(ValidPlayer, GridFortPlayer)}

            Logger.Print("Grid UI initialized for player {OwningPlayer.UUID}.")
        else:
            Logger.Print("Error - failed to get Object Definitions - no GridDevice or EntityManager found!", ?Level := log_level.Error)

    Loop_Update<protected>(InAgent : agent, InLEGOPlayer : lego_fortplayer_grid)<suspends> : void =
        race: 
            InLEGOPlayer.OnUninitLEGOFortplayer.Await()
            loop:
                # Player Selects a new Object to place
                SelectedButtonIndex := GridUI.OnClickedButtonEvent.Await()

                if (SelectedButtonIndex >= 0):
                    # Map the Button Index to the actual Object Index
                    if (ValidUnlockedAsset := GridUI.ObjectDefinitions[SelectedButtonIndex]):
                        InLEGOPlayer.SetIndex_EntityDefinition(SelectedButtonIndex)         

                        if:
                            ValidEntityDefinition := GridDevice.EntityManager.GetGridEntityFromIndex(ValidUnlockedAsset.EntityID)?
                            ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?
                            ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
                        then:
                            InLEGOPlayer.UpdatePlotPreview(ValidPlotDefinition, InLEGOPlayer.PlotPreview)
                            # Force the ObjectPreview to update as usually PreviewDataHasChanged is reset to false after updating the preview
                            set InLEGOPlayer.PreviewDataHasChanged = true
                            InLEGOPlayer.UpdateObjectPreview(ValidObjectDefinition, InLEGOPlayer.ObjectPreview)
                            GridDevice.DisplayDebugMessage(InAgent, ValidPlotDefinition.Name, GridDevice.MessageDevice_EntitySelect)
                        else if:
                            ValidEntityDefinition := GridDevice.EntityManager.GetGridEntityFromIndex(ValidUnlockedAsset.EntityID)? 
                            ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
                        then:
                            InLEGOPlayer.UpdateObjectPreview(ValidObjectDefinition, InLEGOPlayer.ObjectPreview)
                            GridDevice.DisplayDebugMessage(InAgent, ValidObjectDefinition.Name, GridDevice.MessageDevice_EntitySelect)
                    else:    
                        Logger.Print("Error - failed to get Object Definition for index {SelectedButtonIndex}!", ?Level := log_level.Error)
                else:
                    Hide()

    RequestShow(InAgent : agent) : void =
        if (InAgent <> OwningPlayer.FortPlayer?):
            return

        if (IsVisisble?):
            return

        if (GridDevice.IsGridInteractionAllowed[OwningPlayer]):
            Show()

    # Add the grid UI to the player's screen
    Show<public>() : void =
        if (IsVisisble?):
            return

        if (ValidPlayerUI := GetPlayerUI[OwningPlayer.FortPlayer?]):
            ValidPlayerUI.AddWidget(GridUI.GetMainCanvas(), player_ui_slot{InputMode := ui_input_mode.All})
            set IsVisisble = true

    # Remove the grid UI from the player's screen
    Hide<public>() : void =
        if (not IsVisisble?):
            return

        if (ValidPlayerUI := GetPlayerUI[OwningPlayer.FortPlayer?]):
            ValidPlayerUI.RemoveWidget(GridUI.GetMainCanvas())

        set IsVisisble = false

    # Update the grid UI when the player has unlocked new assets
    UpdateGridUI<public>(InLEGOPlayer : lego_fortplayer_grid) : void =
        var ObjectDefinitions : []lego_grid_object_definition = array{}

        # Get all the Object Definitions and pass them to the UI
        for (Index -> GridEntityDefinition : GridDevice.EntityManager.GridEntityDefinitions):
            if:
                ValidObjectDefinition := GridEntityDefinition.ObjectDefinition?
                InLEGOPlayer.GetUnlockedAssets().Find[Index]
            then:
                set ObjectDefinitions += array{ValidObjectDefinition}

        GridUI.Update(ObjectDefinitions)