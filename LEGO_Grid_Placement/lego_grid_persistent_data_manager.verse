using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors/NamedColors }
using { /Verse.org/Random }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { LEGOUtilities }

# ========================================================================================================================================
# Organizes the persistent data for the LEGO Grid Placement system
# ========================================================================================================================================

Tooltip_PersistenceData_AutoSaveIntervalSeconds<public><localizes> : message = "The interval in seconds at which the data is automatically saved, if none is set, AutoSave is disabled."
Tooltip_PersistenceData_OnlyLoadDataForSessionOwner<public><localizes> : message = "If enabled, only load data for the session owner."
Tooltip_PersistenceData_Trigger_RequestSave<public><localizes> : message = "Trigger to manually request a save of the data."
Tooltip_PersistenceData_Trigger_RequestLoad<public><localizes> : message = "Trigger to manually request a load of the data."
Tooltip_PersistenceData_Trigger_RequestFlushDataForPlayer<public><localizes> : message = "Trigger to manually flush the data for a player."

lego_grid_persistence_manager_fndevice_interface<public> := class<concrete>:
    @editable:
        ToolTip := Tooltip_PersistenceData_Trigger_RequestSave
    Trigger_RequestSave : trigger_device = trigger_device{}

    @editable:
        ToolTip := Tooltip_PersistenceData_Trigger_RequestLoad
    Trigger_RequestLoad : trigger_device = trigger_device{}

    @editable:
        ToolTip := Tooltip_PersistenceData_Trigger_RequestFlushDataForPlayer
    Trigger_RequestFlushDataForPlayer : trigger_device = trigger_device{}


# ========================================================================================================================================
# Data structure for a mutable version of the persistent data structure
# ========================================================================================================================================

lego_grid_persistence_log<public> := class(log_channel) {}
lego_grid_persistence_manager<public> := class<concrete>:
    @editable:
        ToolTip := Tooltip_PersistenceData_OnlyLoadDataForSessionOwner
    OnlyLoadDataForSessionOwner : logic = false
    var initialLoadCompleted : logic = false
    var SessionOwnerUUID : int = 0

    @editable:
        ToolTip := Tooltip_PersistenceData_AutoSaveIntervalSeconds
    AutoSaveIntervalSeconds : ?float = option{15.0}

    @editable:
        ToolTip := Tooltip_FNBindingsInterface
    FNBindingsInterface : ?lego_grid_persistence_manager_fndevice_interface = false

    var EntityManager : lego_grid_entity_manager = lego_grid_entity_manager{}
    var IsProcessing : logic = false

    Logger<protected> : log = log{Channel := lego_grid_persistence_log, DefaultLevel := log_level.Normal}

    Initialize<public>(InGridDevice : lego_grid_device) : void =
        set EntityManager = InGridDevice.EntityManager
        if (ValidFNBindingsInterface := FNBindingsInterface?):
            ValidFNBindingsInterface.Trigger_RequestSave.TriggeredEvent.Subscribe(RequestSave)
            ValidFNBindingsInterface.Trigger_RequestLoad.TriggeredEvent.Subscribe(RequestLoad)
            ValidFNBindingsInterface.Trigger_RequestFlushDataForPlayer.TriggeredEvent.Subscribe(RequestFlushDataForPlayer)
        Logger.Print("Initialized LEGO Grid Persistence Manager")


    # Override the current state with the persistent data
    Save<public>(InAgent : agent, InLEGOPlayer : lego_fortplayer_grid)<suspends> : void =
        if (IsProcessing?):
            Logger.Print("Warning - Aborting save: Save already in progress.", ?Level := log_level.Warning)
            return
        set IsProcessing = true

        Logger.Print("----------------------------------------------------------")
        Logger.Print("Starting async saving.")
        Logger.Print("----------------------------------------------------------")
        var StartTime : float = GetSimulationElapsedTime()

        var Offset : vector3 = vector3{}
        if (GridOffset := InLEGOPlayer.GetAssignedArea[EntityManager].GetTransform().Translation):
            set Offset = GridOffset

        if (ValidGridDevice := GetLEGOGridDevice[EntityManager]):
            PersistentData := CreatePersistentData(Offset, InLEGOPlayer, ValidGridDevice)

            if (InAgent.SetLEGOFortPlayerPersistenceData[EntityManager, PersistentData]) {}
            else:
                Logger.Print("ERROR - SetLEGOFortPlayerPersistenceData[] failed", ?Level := log_level.Error)
                Logger.Print("----------------------------------------------------------")
                set IsProcessing = false
                return
        else:
            Logger.Print("ERROR - GetLEGOGridDevice[] failed", ?Level := log_level.Error)
            Logger.Print("----------------------------------------------------------")
            set IsProcessing = false
            return
            
        Logger.Print("Save process succeeded - took {GetElapsedTime(StartTime)} seconds")
        Logger.Print("----------------------------------------------------------")
        set IsProcessing = false


    # Override current state with persistent data
    LoadAndApply(InLEGOPlayer : lego_fortplayer, InData : lego_fortplayer_persistence_data)<suspends> : void =
        if (OnlyLoadDataForSessionOwner?):
            if (initialLoadCompleted?):
                Logger.Print("Warning - Aborting load: Data already loaded.", ?Level := log_level.Warning)
                return
            else:
                set initialLoadCompleted = true

        if (IsProcessing?):
            Logger.Print("Warning - Aborting load: Load/Save already in progress.", ?Level := log_level.Warning)
            return

        set IsProcessing = true
        var StartTime : float = GetSimulationElapsedTime()

        Logger.Print("----------------------------------------------------------")
        Logger.Print("Loading and applying data: {InData.Serialize()}")
        Logger.Print("----------------------------------------------------------")

        if (ValidGridDevice := GetLEGOGridDevice[EntityManager]):
            UnloadPlayerData(InLEGOPlayer, ValidGridDevice)
            LoadPlayerData(InLEGOPlayer, InData.Plots, ValidGridDevice)

        Logger.Print("Loading and applying data completed. Took {GetElapsedTime(StartTime)} seconds")
        Logger.Print("----------------------------------------------------------")
        
        set IsProcessing = false


    # Delete all currently placed objects
    UnloadPlayerData<public>(InLEGOPlayer : lego_fortplayer, InGridDevice : lego_grid_device)<suspends> : void =
        Logger.Print("Start removing existing plot objects.")
        var StartTime : float = GetSimulationElapsedTime()
        var RemovedPlotCount : int = 0
        var RemovedObjectCount : int = 0
        var SoloPropCount : int = 0
        var UpdatedPlotList : []?lego_grid_plot = array{}
        
        for (Index -> Plot : InGridDevice.GetPlots()):
            # Plot owned by player -> remove
            if (Plot?.OwnerUUID = InLEGOPlayer.UUID):                
                if (GridPlot := lego_grid_plot_cells[Plot?]):
                    set RemovedObjectCount += GridPlot.ValidGridObjects.Length
                    GridPlot.ClearAllPlotObjects()

                if (SoloProp := lego_grid_plot_soloprop[Plot?]):
                    SoloProp.Delete()
                    set SoloPropCount += 1
                    set RemovedObjectCount += 1

                set RemovedPlotCount += 1

            # Plot not owned by player, default or no value -> skip
            else:
                set UpdatedPlotList += array{Plot}

        # Update the plot list on the GridDevice
        InGridDevice.SetPlots(UpdatedPlotList)
        Logger.Print("Removed {RemovedPlotCount} Plots with {RemovedObjectCount} GridObjects. Includes {SoloPropCount} SoloProps. Skipped {UpdatedPlotList.Length} Plots (no ownership). Took {GetElapsedTime(StartTime)} seconds")


    # Create plots from saved data and load all associated objects
    LoadPlayerData<public>(InLEGOPlayer : lego_fortplayer, InPlotData : []lego_grid_plot_persistent_data, InGridDevice : lego_grid_device)<suspends> : void =
        Logger.Print("Creating {InPlotData.Length} plots from SaveData.")
        var NewPlots : []?lego_grid_plot = array{}

        # Transform plot location if using optional offset
        var Offset : vector3 = vector3{}
        if (AssignedAreaLocation := InLEGOPlayer.GetAssignedArea[InGridDevice].GetTransform().Translation):
            set Offset = AssignedAreaLocation

        for (Index -> PlotData : InPlotData):
            case (PlotData.PlotType):
                # Create a Grid Plot
                EN_GridPlotPlotType.Cells =>
                    PlotDefinition := lego_grid_plot_definition_cells:
                        OwnerUUID := PlotData.OwnerUUID
                        GridCellSize := PlotData.GridCellSize
                        Columns := PlotData.Columns
                        Rows := PlotData.Rows
                        Layers := PlotData.Layers
                        Category := PlotData.PlotCategory

                    NewPlot := CreatePlotFromDefinition(PlotDefinition, PlotData.Location + Offset, MakeRotationFromYawPitchRollDegrees(0.0, 0.0, PlotData.Rotation))
                    NewPlot.Initialize()

                    # Add all objects to the plot
                    GridObjectData := PlotData.BitpackedGridObjects
                    for (GridObjectIndex -> GridObject : GridObjectData):
                        UnpackedData := GridObject.UnpackGridObjectData()

                        if (ValidEntityDefinition := EntityManager.GetGridEntityFromIndex(UnpackedData.EntityID)?):
                            NewPlot.PlaceGridObject(
                                ValidEntityDefinition, 
                                MakeRotationFromYawPitchRollDegrees(Roll := UnpackedData.Rotation, Pitch := 0.0, Yaw := 0.0), 
                                UnpackedData.Row, UnpackedData.Column, UnpackedData.Layer, InGridDevice)

                                # Sleep to avoid server stall as unpacking is expensive
                                if (Mod[GridObjectIndex, 50] = 0):
                                    Sleep(0.1)
                        else:
                            Logger.Print("ERROR - EntityID not found for GridObject {GridObjectIndex}", ?Level := log_level.Warning)

                    set NewPlots += array{option{NewPlot}}

                # Create a SoloProp
                EN_GridPlotPlotType.SoloProp =>
                    if:
                        UnpackedData := PlotData.BitpackedGridObjects[0].UnpackGridObjectData()
                        ObjectDefinition := EntityManager.GetGridEntityFromIndex(UnpackedData.EntityID)?.ObjectDefinition
                        ValidObjectDefinition := ObjectDefinition?
                    then:
                        SoloPropDef := lego_grid_plot_definition_soloprop:
                            OwnerUUID := PlotData.OwnerUUID
                            CellXSize := PlotData.GridCellSize
                            CellYSize := PlotData.GridCellSize
                            EntityID := UnpackedData.EntityID
                            ObjectDefinition := ObjectDefinition
                            PropAsset := option{ValidObjectDefinition.PropAsset}

                        NewPlot := CreateSoloPropFromDefinition(
                            SoloPropDef, 
                            PlotData.Location + Offset, 
                            MakeRotationFromYawPitchRollDegrees(PlotData.Rotation, 0.0, 0.0))
                        NewPlot.Initialize()

                        set NewPlots += array{option{NewPlot}}
                    else:
                        Logger.Print("ERROR - EntityID not found for SoloProp {Index}", ?Level := log_level.Error)

        InGridDevice.AddPlots(NewPlots)


    # Convert to persistent data - this needs to be async to avoid overloading the server with too many calls while parsing the 3D
    CreatePersistentData(InOffset : vector3, InLEGOPlayer : lego_fortplayer_grid, InGridDevice : lego_grid_device)<suspends> : lego_fortplayer_persistence_data =
        Logger.Print("Converting {InGridDevice.GetPlots().Length} Plots to the persistent data structure.")
        var StartTime : float = GetSimulationElapsedTime()
        var UpdatedPlots : []lego_grid_plot_persistent_data = array{}
        var SoloPropCount : int = 0

        for (Index -> Plot : InGridDevice.GetPlots()):
            if:
                ValidPlot := Plot?
                ValidPlot.OwnerUUID = InLEGOPlayer.UUID or ValidPlot.OwnerUUID = 0 # Only save the Plot if this is owned by the player or a default created plot
            then:
                var OwnerUUID : int = 0
                if (ValidPlot.OwnerUUID = InLEGOPlayer.UUID):
                    set OwnerUUID = InLEGOPlayer.UUID

                PlotSaveData := ValidPlot.ToPersistentGridPlot(InGridDevice, OwnerUUID, InOffset)
                set UpdatedPlots += array{PlotSaveData}

                # Grid Plot
                if (lego_grid_plot_cells[ValidPlot]):
                    Logger.Print("Created persistent data structure for Grid Plot {Index}: {PlotSaveData.Serialize()}")

                # SoloProp
                if (lego_grid_plot_soloprop[ValidPlot]):
                    set SoloPropCount += 1

            Sleep(0.1)
    
        Logger.Print("Created persistent plot save data for {SoloPropCount} SoloProps [details ommitted...]")

        if:
            SkippedPlotCount := InGridDevice.GetPlots().Length - UpdatedPlots.Length
            SkippedPlotCount > 0
        then:
            Logger.Print("Skipped {SkippedPlotCount} plots for player {InLEGOPlayer.UUID} - no ownership.")

        Logger.Print("Player {InLEGOPlayer.UUID} has {InLEGOPlayer.GetUnlockedAssets().Length} unlocked assets.")
        Logger.Print("Completed creating persistent data for Player {InLEGOPlayer.UUID}: contains {InGridDevice.GetPlots().Length} plots. (took {GetElapsedTime(StartTime)} seconds)")

        return lego_fortplayer_persistence_data:
            UUID := InLEGOPlayer.UUID
            UnlockedAssets := InLEGOPlayer.GetUnlockedAssets()
            Plots := UpdatedPlots    

            
    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Request Handlers
    # --------------------------------------------------------------------------------------------------------------------------------------------
    RequestSave<public>(InAgent : ?agent) : void =
        if:
            ValidAgent := InAgent?
            LEGOPlayer := ValidAgent.GetGridPlayer[EntityManager]
        then:
            spawn{Save(ValidAgent, LEGOPlayer)}
        else:
            Logger.Print("ERROR - RequestSave failed: Invalid agent", ?Level := log_level.Error)
        
    RequestLoad<public>(InAgent : ?agent) : void =
        if:
            ValidAgent := InAgent?
            LEGOPlayer := ValidAgent.GetLEGOFortPlayer[EntityManager]
            PersistentData := ValidAgent.GetLEGOFortPlayerPersistenceData[EntityManager]
        then:
            spawn{LoadAndApply(LEGOPlayer, PersistentData)}
        else:
            Logger.Print("ERROR - RequestLoad failed: Invalid agent", ?Level := log_level.Error)

    RequestFlushDataForPlayer<public>(InAgent : ?agent) : void =
        if:
            ValidAgent := InAgent?
            LEGOPlayer := ValidAgent.GetLEGOFortPlayer[EntityManager]

            if (ValidAgent.SetLEGOFortPlayerPersistenceData[EntityManager, lego_fortplayer_persistence_data{}]):
                Logger.Print("Flushed Player persistence data")
            else:
                Logger.Print("ERROR - SetLEGOFortPlayerPersistenceData[] failed", ?Level := log_level.Error)
        else:
            Logger.Print("ERROR - RequestFlushDataForPlayer failed: Invalid agent", ?Level := log_level.Error)
