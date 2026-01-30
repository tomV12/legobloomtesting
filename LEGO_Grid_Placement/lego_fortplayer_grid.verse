using { /Verse.org/Concurrency }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }

using { LEGOUtilities }
using { LEGO_Grid_Placement }

# Enum used to set the input handler on the FortPlayer
en_lego_grid_placement_mode<public> := enum:
    None,
    Object,
    Plot,
    SoloProp

Map_PlotCategory_To_DirectTargeting : [en_lego_grid_plot_category]logic = map:
    en_lego_grid_plot_category.Default => false,
    en_lego_grid_plot_category.Mosaic => false,
    en_lego_grid_plot_category.BlockBuilder => true,
    en_lego_grid_plot_category.Farming => false,
    en_lego_grid_plot_category.SoloProp => false

# ============================================================================================================================================
# A custom version of the lego_fortplauer that extends it with grid placement functionality
# ============================================================================================================================================

new_lego_FortPlayer_Grid<constructor><public>(InFortPlayer : ?player, InFortChar : ?fort_character, InUUID : int) := lego_fortplayer_grid:
    FortPlayer := InFortPlayer
    FortChar := InFortChar
    UUID := InUUID

lego_fortplayer_grid <public> := class<unique>(lego_fortplayer):            
    var StartWithTickEnabled<override> : logic = true
    var TickRate<override> : float = 0.0
    var IsGridEnabled<public> : logic = false
    var GridPlacementMode : en_lego_grid_placement_mode = en_lego_grid_placement_mode.None

    var LastGridPlacementMode<private> : en_lego_grid_placement_mode = en_lego_grid_placement_mode.None
    var Index_EntityDefinition<public> : int = -1
    var Index_PlotDefinition<public> : int = 0
    var UnlockedAssets<protected> : []int = array{}

    var CanPlace_Object<private> : logic = true
    var CanPlace_Plot<public> : logic = false
    
    var Index_Layer<public> : int = 0
    var Index_LastPlot<private> : int = 0
    var Index_Plot<public> : int = 0
    var Index_PlotDelete<public> : ?int = false
    var EntityToPlace<private> : ?lego_grid_entity_definition = false
    var TargetPlot<public> : ?lego_grid_plot = false
    var GridDevice<public> : lego_grid_device = lego_grid_device{}

    var TargetLocation<private> : vector3 = vector3{}
    var SnappedTargetLocation<public> : vector3 = vector3{}
    var TargetCoordinate<public> : ?tuple(int, int, int) = false
    var TargetCoordinate_Delete<public> : ?tuple(int, int, int) = false
    
    var LookAtDistance<private> : float = 100.0
    var InputHandler : lego_input_handler_interface = lego_input_handler_gridobject{}
    var DirectTargeting : logic = false

    var SelectedObject<public> : ?lego_grid_object_base = false

    var Transform_PreviewBox : transform = transform{}
    PlayerDebugDraw<private> : debug_draw = debug_draw{}
    PlotDefinitionDebugDraw<private> : debug_draw = debug_draw{}
    var UsingAssignedAreas<private> : logic = false
    var AssignedBuildZone<public> : ?lego_grid_build_zone = false
    var PreviewBox<public> : ?creative_prop = false
    var PlotPreviewProp<public> : ?creative_prop = false
    var ObjectPreviewProp<public> : ?creative_prop = false

    PlotPreview<public> : lego_grid_plot_preview = lego_grid_plot_preview{}
    ObjectPreview<public> : lego_grid_object_preview = lego_grid_object_preview{}
    var PreviewDataHasChanged : logic = true
    var PreviewHasChanged : logic = true

    ObjectInputHandler<private> : lego_input_handler_gridobject = lego_input_handler_gridobject{}
    PlotInputHandler<private> : LEGO_inputhandler_grid_plot = LEGO_inputhandler_grid_plot{}
    SoloPropInputHandler<private> : lego_input_handler_soloprop = lego_input_handler_soloprop{}

    var CurrentGridCluster : ?lego_grid_cluster = false
    var RelevantGridClusters : []lego_grid_cluster = array{}

    var UsesAreaAssignments<public> : logic = false

    # Used to determine if autosaving is needed, set to true whenever the player places or removes a plot or object
    var HasPendingSave<public> : logic = false

    # Handles all UI related tasks
    GridUIProvider : lego_grid_ui_provider = lego_grid_ui_provider{}


    OnBegin<override>()<suspends> : void =
        Sleep(0.5)
        
        if (Agent := FortPlayer?):
            GridDevice.InitializeInput_ForPlayer(Agent)

            # Unlock all Definitions if UnlockPacks are disabled
            if (GridDevice.EntityManager.DisableUnlockPacks?):
                var AllEntityDefinitionIdices : []int = array{}
                for (Index -> EntityDefinition : GridDevice.EntityManager.GridEntityDefinitions):
                    set AllEntityDefinitionIdices += array{Index}

                SetUnlockedAssets(AllEntityDefinitionIdices)

            if (ValidEntityDefinition := GridDevice.EntityManager.GridEntityDefinitions[Index_EntityDefinition]):
                if (ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?):
                    UpdatePlotPreview(ValidPlotDefinition, PlotPreview)
                if (ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?):
                    UpdateObjectPreview(ValidObjectDefinition, ObjectPreview)

        # Initialize UI
        GridUIProvider.Initialize(Self)

        # Start autosave loop
        spawn{Loop_AutoSavePersistentData()}

    # Loop executed at an interval of TickRate in seconds (0.0 is next server tick, if set above that it can't be below the server tick rate; it will default to this automatically if set too low)
    Tick<override>()<suspends> : void =
        race:
            OnUninitLEGOFortplayer.Await()
            loop:
                Tick_GridInteraction()
                Sleep(TickRate)
    
    # The core functionality of the grid placement system is executed and updated here
    Tick_GridInteraction()<suspends> : void =        
        # Check if the player is in a GridCluster
        if (ValidGridCluster := GridDevice.GridClusters.GetGridClusterAtLocation[FortChar?.GetTransform().Translation]):
            if (CurrentGridCluster <> ValidGridCluster):
                set CurrentGridCluster = option{ValidGridCluster}
                set RelevantGridClusters = array{ValidGridCluster} + GridDevice.GridClusters.GetAdjacentClusters(ValidGridCluster)

            if (GridDevice.GridClusters.EnableDebugVisualization = true):
                GridDevice.GridClusters.CreateActiveClusterDebugVisualization(RelevantGridClusters)
        else:
            set CurrentGridCluster = false
            set RelevantGridClusters = array{}

        # Check if the player is holding the patchwork tool and update IsGridEnabled accordingly
        SetIsGridEnabled()

        if (IsGridEnabled = false):
            return

        # Get the point ahead of the player or offset from the player using the camera's rotation
        set TargetLocation = GetPlayerLookAtLocation(0.0)

        if:
            ValidPlotTuple := GridDevice.IsInAPlot[TargetLocation]
            ValidPlotTuple(0).Category <> en_lego_grid_plot_category.SoloProp
            ValidEntityDefinition := GridDevice.EntityManager.GridEntityDefinitions[Index_EntityDefinition]
            ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
        then:
            ValidPlot := ValidPlotTuple(0)
            set Index_Plot = ValidPlotTuple(1)
            set TargetPlot = option{ValidPlot}

            if:
                PlotCoordinate := GetCoordinateInPlot[TargetLocation, ValidPlot]
            then:
                SetTargetingMode(ValidPlot)
                GetTargetGridCell(Self, ValidPlot, PlotCoordinate)
            else:
                set TargetCoordinate = false
                SetCanPlace_Object(false)

            if:
                ValidCoordinate := TargetCoordinate?
                AreConditionsMet[GridDevice.EntityManager.TypeConditions[ValidObjectDefinition.Type], ValidCoordinate(0), ValidCoordinate(1), ValidCoordinate(2), ValidPlot, ValidObjectDefinition]
            then:
                set GridPlacementMode = en_lego_grid_placement_mode.Object

                if (GridPlacementMode <> LastGridPlacementMode or PreviewDataHasChanged = true):
                    CleanupPreviews()
                    UpdateObjectPreview(ValidObjectDefinition, ObjectPreview)

                set LastGridPlacementMode = GridPlacementMode
                set InputHandler = GetInputHandler(GridPlacementMode)

                # Check whether you're using Assigned Areas within which players can build, if so check whether the target location is within the player's assigned area
                if:
                    UsingAssignedAreas = true and IsDebugModeEnabled(GridDevice)? = false
                    ValidBuildZone := AssignedBuildZone?
                    LocationIsInVolume(TargetLocation, ValidBuildZone.TopLeftLocation, ValidBuildZone.BottomRightLocation, ValidBuildZone.Volume.GetTransform().Scale) = false
                then:
                    SetCanPlace_Object(false)
                else:
                    SetCanPlace_Object(true)
                
                DrawObjectPreview(ValidPlot, ValidCoordinate)
            else if (ValidCoordinate := TargetCoordinate_Delete? or TargetCoordinate?):
                SetCanPlace_Object(false)
                DrawObjectPreview(ValidPlot, ValidCoordinate)
            else:
                SetCanPlace_Object(false)
                CleanupPreviews()
        else if:
            ValidEntityDefinition := GridDevice.EntityManager.GridEntityDefinitions[Index_EntityDefinition]
            ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?

            NewLookAtLocation := 
                GetPlayerLookAtLocation(Max(ValidPlotDefinition.GetCellXSize() * ValidPlotDefinition.GetRows() * 0.66, 
                ValidPlotDefinition.GetCellYSize() * ValidPlotDefinition.GetColumns() * 0.66))

            SnappedX := Floor[(NewLookAtLocation.X-ValidPlotDefinition.GetCellXSize() * ValidPlotDefinition.GetRows() * 0.5) / 16.0] * 16.0
            SnappedY := Floor[(NewLookAtLocation.Y-ValidPlotDefinition.GetCellYSize() * ValidPlotDefinition.GetColumns() * 0.5) / 16.0] * 16.0
        then:
            set GridPlacementMode = en_lego_grid_placement_mode.SoloProp
            set TargetPlot = false

            if (GridPlacementMode <> LastGridPlacementMode or PreviewDataHasChanged = true):
                CleanupPreviews()
                UpdatePlotPreview(ValidPlotDefinition, PlotPreview)

            set InputHandler = GetInputHandler(GridPlacementMode)
            set LastGridPlacementMode = GridPlacementMode
            set SnappedTargetLocation = vector3:
                X := SnappedX
                Y := SnappedY
                Z := TargetLocation.Z
            
            # Check if the Object can be placed at the snapped location
            if:
                PlotOverlap := GridDevice.DoesPlotPreviewOverlap(Self, PlotPreview, ValidPlotDefinition, SnappedTargetLocation)
                PlotOverlap(0) = true
            then:
                # Plot overlaps with another plot -> cannot be placed
                SetCanPlace_Plot(false)
                set Index_PlotDelete = PlotOverlap(2)

            else:
                # Plot does not overlap with another plot
                set Index_PlotDelete = false       
                
                if:
                    UsingAssignedAreas = true and IsDebugModeEnabled(GridDevice)? = false
                    DoesPlotPreviewOverlapBuildZone(PlotPreview, SnappedTargetLocation) = false
                then:
                    # Does not overlap with a build zone -> cannot be placed
                    SetCanPlace_Plot(false)

                else:
                    # -> can be placed
                    SetCanPlace_Plot(true)
            
            CenterLocation := vector3:
                X := SnappedX + PlotPreview.Rows * PlotPreview.CellXSize * 0.5
                Y := SnappedY + PlotPreview.Columns * PlotPreview.CellYSize * 0.5
                Z := GridDevice.GetTransform().Translation.Z

            GridDevice.DrawPlotPreview(PlotPreview, CenterLocation, Self, PreviewHasChanged)
            set PreviewHasChanged = false
        else:
            set Index_PlotDelete = false
            SetCanPlace_Plot(false)
            set TargetPlot = false
            CleanupPreviews()


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Init / Uninit overrides
    # Handle team assignment and area assignment
    # --------------------------------------------------------------------------------------------------------------------------------------------
    Init_LEGOFortplayer<override>()<suspends> : void =
        Sleep(1.0)

        if (TeamAssigner := GetTeamAssigner[GridDevice]):
            TeamAssigner.RequestTeam(Self)
        else:
            Logger.Print("TeamAssigner not found - Player defaulted to team 5!", ?Level := log_level.Error)
           
        Sleep(1.0)
    
        # When we use per-player areas, the area handles loading persistent data
        if (UsesAreaAssignments?):
            AreaAssignmentStatus := RequestAreaAssignment(GridDevice)
            if (not AreaAssignmentStatus?):
                Logger.Print("Failed to assign player to area - player has no assigned area!", ?Level := log_level.Warning)
            else:
                set UsingAssignedAreas = true
        else:
            # Load the persistent data for this player and spawn all the plots and objects
            if (PlayerPersistenceData := FortPlayer?.GetLEGOFortPlayerPersistenceData[GridDevice]):
                GridDevice.Persistence.LoadAndApply(Self, PlayerPersistenceData)
            else:
                Logger.Print("Failed to load persistent data for player {UUID}", ?Level := log_level.Error)

        # Load persistent data
        if (PersistentData := FortPlayer?.GetLEGOFortPlayerPersistenceData[GridDevice]):
            SetUnlockedAssets(PersistentData.UnlockedAssets)
        else:
            Logger.Print("Failed to load persistent data for player {UUID}", ?Level := log_level.Error)

        if (UnlockPack := GridDevice.EntityManager.UnlockPacks[0]):    
            UnlockPack.Unlock(FortPlayer)

        set LookAtDistance = GridDevice.LookAtDistance

        (super:)Init_LEGOFortplayer()

    UnInit_LEGOFortplayer<override>()<suspends> : void =
        (super:)UnInit_LEGOFortplayer() # Stop tick before leaving team and unassigning area

        if (TeamAssigner := GetTeamAssigner[GridDevice]):
            TeamAssigner.RequestLeaveTeam(Self)
            
        if (UsesAreaAssignments?):
            AreaAssignmentStatus := RequestAreaUnassignment(GridDevice)
            if (not AreaAssignmentStatus?):
                Logger.Print("Failed to unassign player from area - thre might be a blocked area now!", ?Level := log_level.Warning)

        CleanupPreviews()


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Persistent Data autosaving
    # --------------------------------------------------------------------------------------------------------------------------------------------
    Loop_AutoSavePersistentData()<suspends> : void =
        if (ValidGridDevice := GetLEGOGridDevice[GridDevice]):
            Logger.Print("Starting AutoSave loop for player {UUID}")

            if (AutoSaveIntervalSeconds := ValidGridDevice.Persistence.AutoSaveIntervalSeconds?):            
                race:
                    OnUninitLEGOFortplayer.Await()
                    loop:
                        Sleep(AutoSaveIntervalSeconds)

                        # HasPendingSave is set true whenever the player places or removes a plot or object
                        if (HasPendingSave?):
                            Logger.Print("Pending Changes: Autosaving persistent data for player {UUID}...")
                            ValidGridDevice.Persistence.RequestSave(FortPlayer)

                            if (PlayerPersistenceData := FortPlayer?.GetLEGOFortPlayerPersistenceData[ValidGridDevice]):
                                set HasPendingSave = false
        else:
            Logger.Print("Start AutoSave loop failed for player {UUID}! - Failed to get GridDevice.", ?Level := log_level.Error)


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Unlocked Assets
    # --------------------------------------------------------------------------------------------------------------------------------------------
    GetUnlockedAssets<public>()<transacts> : []int =
        UnlockedAssets
    
    SetUnlockedAssets<public>(InUnlockedAssets : []int) : void =
        set UnlockedAssets = InUnlockedAssets
        set HasPendingSave = true

    UnlockAsset<public>(InIndex : int) : void =
        if (UnlockedAssets.Find[InIndex]):
            return
            
        set UnlockedAssets += array{InIndex}
        GridUIProvider.UpdateGridUI(Self)
        set HasPendingSave = true


    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Utilities
    # --------------------------------------------------------------------------------------------------------------------------------------------
    GetPlayerLookAtLocation(Offset : float)<transacts> : vector3 =
        if (Character := FortChar?):
            var PlayerLookAtLocation : vector3 = vector3{}
            
            if (DirectTargeting = false):
                LocalForward := Character.GetTransform().Rotation.GetLocalForward()
                CameraYOffset := DotProduct(Character.GetViewLocation() - Character.GetTransform().Translation, Character.GetTransform().Rotation.GetLocalRight())
                set PlayerLookAtLocation =  Character.GetTransform().Translation + Character.GetTransform().Rotation.GetLocalRight() * CameraYOffset + (LocalForward * (LookAtDistance + Offset))
            else:
                CameraRotation := Character.GetViewRotation()
                LocalForward := CameraRotation.GetLocalForward()
                PlayerCameraDistance := GetDistanceBetweenVector3(Character.GetViewLocation(), Character.GetTransform().Translation)
                set PlayerLookAtLocation = Character.GetViewLocation() + (LocalForward * (PlayerCameraDistance + LookAtDistance + Offset))
            
            return PlayerLookAtLocation

        else:
            return vector3{}

    # Get the input handler associated with the placement mode the player is set to
    GetInputHandler<public>(InGridMode : en_lego_grid_placement_mode) : lego_input_handler_interface =
        case (InGridMode):
            en_lego_grid_placement_mode.None =>
                lego_input_handler_gridobject{}

            en_lego_grid_placement_mode.Object =>
                ObjectInputHandler

            en_lego_grid_placement_mode.Plot =>
                PlotInputHandler

            en_lego_grid_placement_mode.SoloProp =>
                SoloPropInputHandler


    GetTargetGridCell<public>(Player : lego_fortplayer_grid, Plot : lego_grid_plot, Coordinate : tuple(int, int, int)) : void =
        set Player.TargetCoordinate = option{Coordinate}
        
        case (DirectTargeting):
            true =>
                if:
                    MaybeObject := Plot.GridObjects[Coordinate(0)][Coordinate(1)][Coordinate(2)]?
                then:
                    set TargetCoordinate_Delete = option{Coordinate}
                    set TargetCoordinate = false
                    return

                if (Coordinate(2) < Plot.Layers - 1):
                    FlooredZ := Max(0, Coordinate(2))
                    set SelectedObject = false
                    set Index_Layer = Coordinate(2)
                    set TargetCoordinate = option{(Coordinate(0), Coordinate(1), FlooredZ)}
                    set TargetCoordinate_Delete = false
                else:
                    set SelectedObject = false
                    set Index_Layer = Coordinate(2)
                    set TargetCoordinate = false
                    set TargetCoordinate_Delete = false
            
            false =>
                for (Index := 0..Plot.Layers - 1):
                    if (not Plot.GridObjects[Coordinate(0)][Coordinate(1)][Index]?):
                        set SelectedObject = false
                        set Index_Layer = Index
                        set TargetCoordinate = option{(Coordinate(0), Coordinate(1), Index)}
                        set TargetCoordinate_Delete = option{(Coordinate(0), Coordinate(1), Index - 1)}
                        return
                        
                    set Index_Layer = Index + 1

                set TargetCoordinate = false
                set TargetCoordinate_Delete = option{(Coordinate(0), Coordinate(1), Index_Layer - 1)}

            _=> {}


    DrawObjectPreview<private>(Plot : lego_grid_plot, Coordinates : tuple(int, int, int)) : void =
        var PreviewZ : float = 0.0

        if (DirectTargeting = false):
            if (TempObject := Plot.GridObjects[Coordinates(0)][Coordinates(1)][Index_Layer - 1]?):
                set PreviewZ = TempObject.Location.Z + TempObject.Height
            else:
                set PreviewZ = Plot.Location.Z
        else:
            set PreviewZ = Plot.Location.Z + Plot.GridCellSize * Coordinates(2)

        Location := vector3:
            X := Plot.Location.X + Coordinates(0) * Plot.GridCellSize + Plot.GridCellSize * 0.5
            Y := Plot.Location.Y + Coordinates(1) * Plot.GridCellSize + Plot.GridCellSize * 0.5
            Z := PreviewZ + NearZeroInt

        set Transform_PreviewBox = transform:
            Translation := Location
            Rotation := IdentityRotation()
            Scale := vector3:
                X := Plot.GetCellXSize() / 100.0
                Y := Plot.GetCellYSize() / 100.0
                Z := ObjectPreview.Height / 100.0
        
        if (PreviewHasChanged = true):
            CleanupPreviews()
            
            if:
                CanPlace_Object = true
                ValidProp := SpawnProp(GridDevice.PreviewBox_Object_Green, Transform_PreviewBox)(0)?
            then:
                set PreviewBox = option{ValidProp}
                AssetToSpawn := ObjectPreview.PropAsset
                set ObjectPreview.Location = Location

                if (ValidObjectPreviewProp := SpawnProp(AssetToSpawn, Location, ObjectPreview.Rotation)(0)?):
                    set ObjectPreviewProp = option{ValidObjectPreviewProp}
            else:
                set Transform_PreviewBox.Scale.Z = Plot.GetCellZSize() / 100.0
                
                if:
                    CanPlace_Object = false
                    ValidPreviewBox := SpawnProp(GridDevice.PreviewBox_Object_Red, Transform_PreviewBox)(0)?
                then:
                    set PreviewBox = option{ValidPreviewBox}
                    set ObjectPreview.Location = Location
        else:
            set Transform_PreviewBox.Scale.Z = Plot.GetCellZSize() / 100.0
            
            if (PreviewBox?.TeleportTo[Transform_PreviewBox]) 
            {}

            if:
                ObjectPreviewProp?.TeleportTo[Location, ObjectPreview.Rotation]
            then:
                set ObjectPreview.Location = Location

        set PreviewHasChanged = false

    # Remove all placement previews, use this when switching placement modes or turning off grid functionality
    CleanupPreviews<public>() : void =
        if (ValidPlotPreview := PreviewBox?):
            ValidPlotPreview.Dispose()

        if (ValidSoloPropPreview := PlotPreviewProp?):
            ValidSoloPropPreview.Hide()
            ValidSoloPropPreview.Dispose()

        if (ValidObjectPreview := ObjectPreviewProp?):
            ValidObjectPreview.Hide()
            ValidObjectPreview.Dispose()

        set PreviewHasChanged = true

    # Update the plot or soloprop shown when grid functionality is on and the player has unlocked assets to place
    UpdatePlotPreview<public>(PlotDefinition : lego_grid_plot_definition, Preview : lego_grid_plot_preview) : void =
        if (PreviewDataHasChanged = true):    
            PlotPreview.SetPropAsset(PlotDefinition.GetProp())

            set Preview.Rows = PlotDefinition.GetRows()
            set Preview.Columns = PlotDefinition.GetColumns()
            set Preview.Rotation = IdentityRotation()
            set Preview.Rotation_90 = 0
            set Preview.GridCellSize = PlotDefinition.GetGridCellSize()
            set Preview.CellXSize = PlotDefinition.GetCellXSize()
            set Preview.CellYSize = PlotDefinition.GetCellYSize()
            set Preview.CellZSize = 100.0
            set PreviewDataHasChanged = false
            set PreviewHasChanged = true

            if:
                ValidSoloPropDefinition := lego_grid_plot_definition_soloprop[PlotDefinition]
                ValidEntityDefinition := GridDevice.EntityManager.GridEntityDefinitions[ValidSoloPropDefinition.EntityID]
                ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
            then:
                set Preview.Height = ValidObjectDefinition.Height / 100.0
            else:
                set Preview.Height = Preview.GridCellSize / 100.0

    # Update the grid object shown when grid functionality is on and the player has unlocked assets to place
    UpdateObjectPreview<public>(ObjectDefinition : lego_grid_object_definition, Preview : lego_grid_object_preview) : void =
        if (PreviewDataHasChanged = true):  
            ObjectPreview.SetPropAsset(ObjectDefinition.PropAsset)

            set Preview.Category = ObjectDefinition.Category
            set Preview.PropAsset = ObjectDefinition.PropAsset
            set Preview.Height = ObjectDefinition.Height
            set Preview.CanBuildUpon = ObjectDefinition.CanBuildUpon
            set PreviewDataHasChanged = false
            set PreviewHasChanged = true

    # Switch between different InputHandlers to change how you place an entity (as a grid object or a soloprop), or to place a plot if you enable suport for placing plots
    UpdateGridPlacementMode<private>(InMode : en_lego_grid_placement_mode) : void =
        if (InMode = GridPlacementMode):
            return
        
        Logger.Print("Updating GridPlacementMode to")
        CleanupPreviews()
        set GridPlacementMode = InMode
        set InputHandler = GetInputHandler(InMode)

    # Toggle grid functionality on or off based on whether the player is holding an item or not
    SetIsGridEnabled() : void =
        if:
            Player := FortPlayer?
            GridDevice.Button_GridToggle.IsHoldingItem[Player, 0]
            IsGridEnabled = false
        then:
            # Player is allowed to interact with the grid
            set IsGridEnabled = true
            GridDevice.InitializeInput_ForPlayer(Player)
        else if:
            Player := FortPlayer?
            not GridDevice.Button_GridToggle.IsHoldingItem[Player, 0]
            IsGridEnabled = true
        then:
            # Player is not allowed to interact with the grid
            set IsGridEnabled = false
            GridDevice.UnregisterAllInput_ForPlayer(Player)
            CleanupPreviews()
            set PreviewHasChanged = true
            GridDevice.HideDebugMessage(Player, GridDevice.MessageDevice_EntitySelect)
    
    GetCanPlace_Object<public>()<transacts> : logic =
        CanPlace_Object
    
    SetCanPlace_Object<public>(InLogic : logic) : void =       
        if (CanPlace_Object <> InLogic):
            set PreviewHasChanged = true
            set CanPlace_Object = InLogic

    SetCanPlace_Plot<public>(InLogic : logic) : void =
        if (CanPlace_Plot <> InLogic):
            set PreviewHasChanged = true
            set CanPlace_Plot = InLogic

    SetIndex_EntityDefinition<public>(InIndex : int) : void =
        set Index_EntityDefinition = InIndex
        set PreviewDataHasChanged = true

    SetIndex_PlotDefinition<public>(InIndex : int) : void =
        set Index_PlotDefinition = InIndex
        set PreviewDataHasChanged = true
        
    SetTargetingMode(InPlot : lego_grid_plot) : void =
        if (IsDirectTargeting := Map_PlotCategory_To_DirectTargeting[InPlot.Category]):
            set DirectTargeting = IsDirectTargeting
        else: 
            set DirectTargeting = false

    DoesPlotPreviewOverlapBuildZone(InPlotPreview : lego_grid_plot_preview, InTargetLocation : vector3)<transacts> : logic =
        if (ValidBuildZone := AssignedBuildZone?):
            # Check if any build zone overlaps the plot to be placed
            NewPlotCoordinates := GridDevice.GetPlotPreviewCornerLocations(InPlotPreview, InTargetLocation)
            
            BuildZone_TopLeftLocation := GetVector2_FromVector3(NewPlotCoordinates(0))
            BuildZone_RightLocation := GetVector2_FromVector3(NewPlotCoordinates(1))

            Zone_TopLeftLocation := GetVector2_FromVector3(ValidBuildZone.TopLeftLocation)
            Zone_BottomRightLocation := GetVector2_FromVector3(ValidBuildZone.BottomRightLocation)

            if (DoAlignedRectanglesOverlap(BuildZone_TopLeftLocation, BuildZone_RightLocation, Zone_TopLeftLocation, Zone_BottomRightLocation) = true):
                return true
                
        return false
