using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Simulation }
using { LEGOUtilities }

# ============================================================================================================================================
# Input Handlers handle input passed from InputTriggers held in the lego_grid_device and contextually perform the action associated with the input trigger
# The current Input Handler is automatically changed in lego_fortplayer_grid based on the asset selected to be placed and whether it's in a plot or not for entities
# ============================================================================================================================================

# ------------------------------------------------------------------------------------------------------------------
# Handles input when placing an asset inside a cell of a multi-cell plot, used when a multi-cell plot is present at the target location
# ------------------------------------------------------------------------------------------------------------------

lego_input_handler_gridobject<public> := class(lego_input_handler_interface):    
    Place<override>(Agent : agent, Player : lego_fortplayer_grid, GridDevice : lego_grid_device): void =
        if:
            Player.GetCanPlace_Object() = true
            ValidEntityDefinition := GridDevice.EntityManager.GridEntityDefinitions[Player.Index_EntityDefinition]
            Coordinate := Player.TargetCoordinate?
            Plot := Player.TargetPlot?
            Layer := Player.Index_Layer
        then:
            if (MaybeObject := Plot.GetGridObject(Coordinate, Layer)?):
                return
            else:
                if (Player.DirectTargeting = false):
                    Plot.PlaceGridObject(ValidEntityDefinition, Player.ObjectPreview.Rotation, Coordinate(0), Coordinate(1), Layer, GridDevice)
                else:
                    Plot.PlaceGridObject_Direct(ValidEntityDefinition, Player.ObjectPreview.Rotation, Coordinate(0), Coordinate(1), Coordinate(2), GridDevice)

                GridDevice.OnGridObjectPlaced.Signal((Agent, ValidEntityDefinition.Name, Player.ObjectPreview.Location))
        set Player.HasPendingSave = true
                    
    Delete<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device): void =
        # Check for SoloProp to override delete if present
        if:
            SoloProp := GridDevice.GetPlotAtIndex[Player.Index_PlotDelete?]
            SoloProp.OwnerUUID = Player.UUID
            GridDevice.RemovePlotAtIndex[Player.Index_PlotDelete?]
        then:
            spawn{SoloProp.Delete()}
            set Player.HasPendingSave = true
            set Player.Index_PlotDelete = false
            return
        
        if:
            Player.DirectTargeting = false
            Coordinate := Player.TargetCoordinate_Delete?
            Plot := Player.TargetPlot?
            Object := Plot.GridObjects[Coordinate(0)][Coordinate(1)][Coordinate(2)]?
        then:
            Plot.DeleteGridObject(Coordinate(0), Coordinate(1), Coordinate(2))
        else if:
            Player.DirectTargeting = true
            Coordinate := Player.TargetCoordinate_Delete?
            Plot := Player.TargetPlot?
            Object := Plot.GridObjects[Coordinate(0)][Coordinate(1)][Coordinate(2)]
        then:
            Plot.DeleteGridObject(Coordinate(0), Coordinate(1), Coordinate(2))
            
        set Player.HasPendingSave = true

    RotateAntiClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        set Player.ObjectPreview.Rotation_90 = Player.ObjectPreview.Rotation_90.IncrementWrapped(3)
        set Player.ObjectPreview.Rotation = MakeRotation(
            Axis :=vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.ObjectPreview.Rotation_90 * DegreesToRadians(90.0))

    RotateClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device): void =
        set Player.ObjectPreview.Rotation_90 = Player.ObjectPreview.Rotation_90.DecrementWrapped(3)
        set Player.ObjectPreview.Rotation = MakeRotation(
            Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.ObjectPreview.Rotation_90 * DegreesToRadians(90.0))

    Previous<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =     
        if (Player.GetUnlockedAssets().Length > 0):
            Player.SetIndex_EntityDefinition(Player.Index_EntityDefinition.DecrementWrapped(Player.GetUnlockedAssets().Length - 1))
            Entities := GridDevice.EntityManager.GetGridEntityDefinitions()            
            if:
                ValidIndex := Player.GetUnlockedAssets()[Player.Index_EntityDefinition]
                ValidEntityDefinition := Entities[ValidIndex]
                ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
            then:
                Player.UpdateObjectPreview(ValidObjectDefinition, Player.ObjectPreview)
                GridDevice.DisplayDebugMessage(Agent, ValidObjectDefinition.GetName(), GridDevice.MessageDevice_EntitySelect)

    Next<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =
        if (Player.GetUnlockedAssets().Length > 0):
            Player.SetIndex_EntityDefinition(Player.Index_EntityDefinition.IncrementWrapped(Player.GetUnlockedAssets().Length - 1))
            Entities := GridDevice.EntityManager.GetGridEntityDefinitions()            
            if:
                ValidIndex := Player.GetUnlockedAssets()[Player.Index_EntityDefinition]
                ValidEntityDefinition := Entities[ValidIndex]
                ValidObjectDefinition := ValidEntityDefinition.ObjectDefinition?
            then:
                Player.UpdateObjectPreview(ValidObjectDefinition, Player.ObjectPreview)
                GridDevice.DisplayDebugMessage(Agent, ValidObjectDefinition.GetName(), GridDevice.MessageDevice_EntitySelect)

    SwitchTargeting<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =        
        if (Player.DirectTargeting = true):
            set Player.DirectTargeting = false
        else:
            set Player.DirectTargeting = true


# ------------------------------------------------------------------------------------------------------------------
# Handle input when placing an asset as a free-standing asset that occupies a single-cell plot, used when no target multi-cell plot is present at the target location
# ------------------------------------------------------------------------------------------------------------------

lego_input_handler_soloprop<public> := class(lego_input_handler_interface):
    Place<override>(Agent : agent, Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void = 
        if: 
            ValidEntityDefinition := Player.GridDevice.EntityManager.GridEntityDefinitions[Player.Index_EntityDefinition]
            ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?
        then:
            if (Player.CanPlace_Plot = true):
                NewPlotLocation := vector3:
                    X := Player.SnappedTargetLocation.X
                    Y := Player.SnappedTargetLocation.Y
                    Z := GridDevice.GetTransform().Translation.Z
                NewPlot : lego_grid_plot = ValidPlotDefinition.CreatePlot(Player.PlotPreview, NewPlotLocation, Player.PlotPreview.Rotation)
                set NewPlot.OwnerUUID = Player.UUID
                
                GridDevice.AddPlots(array{option{NewPlot}})
                spawn{NewPlot.Initialize()}
                GridDevice.OnGridObjectPlaced.Signal((Agent, ValidPlotDefinition.Name, NewPlotLocation))
        set Player.HasPendingSave = true

    Delete<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        if:
            SoloProp := GridDevice.GetPlotAtIndex[Player.Index_PlotDelete?]
            SoloProp.OwnerUUID = Player.UUID
            GridDevice.RemovePlotAtIndex[Player.Index_PlotDelete?]
        then:
            spawn{SoloProp.Delete()}
            set Player.HasPendingSave = true
            set Player.Index_PlotDelete = false

    RotateAntiClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        TempColumns := Player.PlotPreview.Columns
        TempRows := Player.PlotPreview.Rows
        TempCellXSize := Player.PlotPreview.CellXSize
        TempCellYSize := Player.PlotPreview.CellYSize
        
        set Player.PlotPreview.Columns = TempRows
        set Player.PlotPreview.Rows = TempColumns
        set Player.PlotPreview.CellXSize = TempCellYSize
        set Player.PlotPreview.CellYSize = TempCellXSize
        set Player.PlotPreview.Rotation_90 = Player.PlotPreview.Rotation_90.IncrementWrapped(3)
        set Player.PlotPreview.Rotation = MakeRotation(
            Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.PlotPreview.Rotation_90 * DegreesToRadians(90.0))

    RotateClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        TempColumns := Player.PlotPreview.Columns
        TempRows := Player.PlotPreview.Rows
        TempCellXSize := Player.PlotPreview.CellXSize
        TempCellYSize := Player.PlotPreview.CellYSize
        
        set Player.PlotPreview.Columns = TempRows
        set Player.PlotPreview.Rows = TempColumns
        set Player.PlotPreview.CellXSize = TempCellYSize
        set Player.PlotPreview.CellYSize = TempCellXSize
        set Player.PlotPreview.Rotation_90 = Player.PlotPreview.Rotation_90.DecrementWrapped(3)
        set Player.PlotPreview.Rotation = MakeRotation(
            Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.PlotPreview.Rotation_90 * DegreesToRadians(90.0))

    Previous<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =     
        if (Player.GetUnlockedAssets().Length > 0):    
            Player.SetIndex_EntityDefinition(Player.Index_EntityDefinition.DecrementWrapped(Player.GetUnlockedAssets().Length - 1))            
            Entities := GridDevice.EntityManager.GetGridEntityDefinitions()            
            if:
                ValidIndex := Player.GetUnlockedAssets()[Player.Index_EntityDefinition]
                ValidEntityDefinition := Entities[ValidIndex]
                ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?
            then:
                Player.UpdatePlotPreview(ValidPlotDefinition, Player.PlotPreview)
                GridDevice.DisplayDebugMessage(Agent, ValidPlotDefinition.Name, GridDevice.MessageDevice_EntitySelect)

    Next<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =
        if (Player.GetUnlockedAssets().Length > 0):    
            Player.SetIndex_EntityDefinition(Player.Index_EntityDefinition.IncrementWrapped(Player.GetUnlockedAssets().Length - 1))            
            Entities := GridDevice.EntityManager.GetGridEntityDefinitions()            
            if:
                ValidIndex := Player.GetUnlockedAssets()[Player.Index_EntityDefinition]
                ValidEntityDefinition := Entities[ValidIndex]
                ValidPlotDefinition := ValidEntityDefinition.SoloPropDefinition?
            then:
                Player.UpdatePlotPreview(ValidPlotDefinition, Player.PlotPreview)
                GridDevice.DisplayDebugMessage(Agent, ValidPlotDefinition.Name, GridDevice.MessageDevice_EntitySelect)

    SwitchTargeting<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =        
        if (Player.DirectTargeting = true):
            set Player.DirectTargeting = false
        else:
            set Player.DirectTargeting = true


# ------------------------------------------------------------------------------------------------------------------   
# Handle input when placing a multi-cell plot, not used in the template but could be used to place a pre-defined plot at a custom location (e.g. a 4x4 plot for a farming sim)
# ------------------------------------------------------------------------------------------------------------------   

LEGO_inputhandler_grid_plot<public> := class(lego_input_handler_interface):
    Place<override>(Agent : agent, Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void = 
        if: 
            PlotDefinition := GridDevice.PlotDefinitions[Player.Index_PlotDefinition]
            Player.CanPlace_Plot = true
        then:
            NewPlotLocation := vector3:
                X := Player.SnappedTargetLocation.X
                Y := Player.SnappedTargetLocation.Y
                Z := GridDevice.GetTransform().Translation.Z

            NewPlot : lego_grid_plot = PlotDefinition.CreatePlot(Player.PlotPreview, NewPlotLocation, Player.PlotPreview.Rotation)
            set NewPlot.OwnerUUID = Player.UUID

            GridDevice.AddPlots(array{option{NewPlot}})
            NewPlot.DrawPlot(GridDevice.PreviewBox_Plot_White)
            spawn{NewPlot.Initialize()}
            set Player.HasPendingSave = true

    Delete<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        if:
            Plot := GridDevice.GetPlotAtIndex[Player.Index_Plot]
            Plot.OwnerUUID = Player.UUID
            GridDevice.RemovePlotAtIndex[Player.Index_Plot]
        then:
            spawn{Plot.Delete()}
            set Player.HasPendingSave = true

    RotateAntiClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        TempColumns := Player.PlotPreview.Columns
        TempRows := Player.PlotPreview.Rows
        TempCellXSize := Player.PlotPreview.CellXSize
        TempCellYSize := Player.PlotPreview.CellYSize
        
        set Player.PlotPreview.Columns = TempRows
        set Player.PlotPreview.Rows = TempColumns
        set Player.PlotPreview.CellXSize = TempCellYSize
        set Player.PlotPreview.CellYSize = TempCellXSize
        set Player.PlotPreview.Rotation_90 = Player.PlotPreview.Rotation_90.IncrementWrapped(3)
        set Player.PlotPreview.Rotation = MakeRotation(
            Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.PlotPreview.Rotation_90 * DegreesToRadians(90.0))

    RotateClockwise<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        TempColumns := Player.PlotPreview.Columns
        TempRows := Player.PlotPreview.Rows
        TempCellXSize := Player.PlotPreview.CellXSize
        TempCellYSize := Player.PlotPreview.CellYSize
        
        set Player.PlotPreview.Columns = TempRows
        set Player.PlotPreview.Rows = TempColumns
        set Player.PlotPreview.CellXSize = TempCellYSize
        set Player.PlotPreview.CellYSize = TempCellXSize
        set Player.PlotPreview.Rotation_90 = Player.PlotPreview.Rotation_90.DecrementWrapped(4)
        set Player.PlotPreview.Rotation = MakeRotation(
            Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, 
            AngleRadians := Player.PlotPreview.Rotation_90 * DegreesToRadians(90.0))

    Previous<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =
        Player.SetIndex_PlotDefinition(Player.Index_PlotDefinition.DecrementWrapped(GridDevice.PlotDefinitions.Length - 1))            
        if:
            ValidPlotDefinition := GridDevice.PlotDefinitions[Player.Index_PlotDefinition]
        then:
            Player.UpdatePlotPreview(ValidPlotDefinition, Player.PlotPreview)
            GridDevice.DisplayDebugMessage(Agent, ValidPlotDefinition.Name, GridDevice.MessageDevice_EntitySelect)

    Next<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void =
        Player.SetIndex_PlotDefinition(Player.Index_PlotDefinition.IncrementWrapped(GridDevice.PlotDefinitions.Length - 1))
            
        if (ValidPlot := GridDevice.PlotDefinitions[Player.Index_PlotDefinition]):
            Player.UpdatePlotPreview(ValidPlot, Player.PlotPreview)
            GridDevice.DisplayDebugMessage(Agent, ValidPlot.Name, GridDevice.MessageDevice_EntitySelect)

    SwitchTargeting<override>(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void =
        if (Player.DirectTargeting = true):
            set Player.DirectTargeting = false
        else:
            set Player.DirectTargeting = true
