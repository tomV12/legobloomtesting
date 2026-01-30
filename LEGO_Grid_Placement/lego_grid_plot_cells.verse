using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Colors }
using { /Fortnite.com/Devices }

using {LEGOUtilities}

# ============================================================================================================================================
# Represents a plot of cells in the grid
# ============================================================================================================================================

Tooltip_GridPlot_Cells_Name<public><localizes> : message = "The name of the grid plot."
Tooltip_GridPlot_Cells_Category<public><localizes> : message = "The category of the grid plot, that can be used to define what can be placed in it."
Tooltip_GridPlot_Cells_Columns<public><localizes> : message = "The number of columns in the grid plot."
Tooltip_GridPlot_Cells_Rows<public><localizes> : message = "The number of rows in the grid plot."
Tooltip_GridPlot_Cells_Layers<public><localizes> : message = "The number of layers in the grid plot."
Tooltip_GridPlot_Cells_GridCellSize<public><localizes> : message = "The size of the grid cell in studs."
Tooltip_GridPlot_Cells_InstanceMarkers<public><localizes> : message = "The instance markers that represent the grid plot."
Tooltip_GridPlot_Cells_PlotPreview<public><localizes> : message = "The plot preview that represents the grid plot."

en_lego_grid_plot_category<public> := enum<persistable>{
    Default,
    Mosaic,
    BlockBuilder,
    Farming,
    SoloProp
}

CreatePlotFromDefinition<constructor><public>(PlotDefinition : lego_grid_plot_definition_cells, PlotLocation : vector3, PlotRotation : rotation) := lego_grid_plot_cells:
    OwnerUUID := PlotDefinition.OwnerUUID
    Columns := PlotDefinition.Columns
    Rows := PlotDefinition.Rows
    Layers := PlotDefinition.Layers
    GridCellSize := PlotDefinition.GridCellSize
    Category := PlotDefinition.Category

    Location := PlotLocation
    CenterLocation := vector3:
        X := PlotLocation.X + PlotDefinition.Rows * PlotDefinition.GetCellXSize() * 0.5
        Y := PlotLocation.Y + PlotDefinition.Columns * PlotDefinition.GetCellYSize() * 0.5
        Z := PlotLocation.Z

    block:
        DebugLog("AttemptingCreatePlot at location {PlotLocation}")

lego_grid_plot_definition_cells<public> := class<concrete><unique>(lego_grid_plot_definition):
    @editable:
        ToolTip := Tooltip_GridPlot_Cells_Name
    var Name<override> : string = ""

    @editable:
        ToolTip := Tooltip_GridPlot_Cells_Name
    Category : en_lego_grid_plot_category = en_lego_grid_plot_category.Default

    @editable:
        ToolTip := Tooltip_GridPlot_Cells_Columns
    Columns<public> : int = 0

    @editable:
        ToolTip := Tooltip_GridPlot_Cells_Rows
    Rows<public> : int = 0

    @editable:
        ToolTip := Tooltip_GridPlot_Layers
    Layers<public> : int = 0

    @editable:
        ToolTip := Tooltip_GridPlot_Cells_Layers
    GridCellSize_InStuds<public> : int = 1

    var GridCellSize<public> : float = 0.0

    # This value is initialized by the EntityManager OnBegin() and represents the index of the object in the list of objects
    var EntityID : int = -1

    @editable
    InstanceMarkers : []?creative_prop = array{}

    GetCellXSize<override>()<transacts> : float =
        GridCellSize

    GetCellYSize<override>()<transacts> : float =
        GridCellSize

    GetCellZSize<override>()<transacts> : float =
        GridCellSize

    GetGridCellSize<override>()<transacts> : float =
        return GridCellSize

    CreatePlot<override>(PlotPreview : lego_grid_plot_preview, Location : vector3, PlacementRotation : rotation) : lego_grid_plot_cells = 
        CreatePlotFromDefinition(Self, Location, PlacementRotation)

    CreatePlot<override>(Location : vector3, PlacementRotation : rotation) : lego_grid_plot_cells =
        CreatePlotFromDefinition(Self, Location, PlacementRotation)

    ConvertDimensions<override>() : void =
        set GridCellSize = GetCmFromStuds(GridCellSize_InStuds)

    GetProp<override>()<transacts> : ?creative_prop_asset =
        false

    GetColumns<override>()<transacts> : int =
        Columns

    GetRows<override>()<transacts> : int =
        Rows

    GetName<override>() : string =
        Name

    SetName<override>(NewName:string) : void =
        set Name = NewName

    SpawnInstances(GridDevice : lego_grid_device) : void =
        for (MaybeInstanceMarker : InstanceMarkers, ValidInstanceMarker := MaybeInstanceMarker?):
            Plot := CreatePlotFromDefinition(Self, ValidInstanceMarker.GetTransform().Translation, IdentityRotation())
            Plot.DrawPlot(GridDevice.PreviewBox_Plot_White)
            GridDevice.AddPlot(Plot)
            spawn{Plot.Initialize()}

    Initialize<override>() : void =
        ConvertDimensions()


lego_grid_plot_cells<public> := class<concrete>(lego_grid_plot):
    # Construct the 3D array so that we're ready to set its elements
    Initialize<override>()<suspends> : void =
        set GridObjects =
            for (Row := 0..Rows - 1):
                Sleep(0.0)
                for (Column := 0..Columns - 1):
                    for (Layer := 0..Layers - 1):
                        false

    GetCellXSize<override>()<transacts> : float = 
        GridCellSize

    GetCellYSize<override>()<transacts> : float =
        GridCellSize

    GetCellZSize<override>()<transacts> : float =
        GridCellSize

    GetGridCellSize<override>()<transacts> : float =
        GridCellSize

    SetLocation<public>(NewLocation: vector3) : void =
        set Location = NewLocation

    FillLayer<public>(Layer: int, EntityDefinition : lego_grid_entity_definition) : void =
        for:
            Row := 0..Rows - 1
            Column := 0..Columns - 1
        do:
            SetGridObject(EntityDefinition, Row, Column, Layer)

    SpawnGridObjects<public>()<suspends> : void =
        for:
            RowIndex := 0..Rows - 1
            ColumnIndex := 0..Columns - 1
            LayerIndex := 0..Layers - 1
        do:
            if (ObjectToSpawn := GridObjects[RowIndex][ColumnIndex][LayerIndex]?):
                ObjectToSpawn.SpawnProp()

    GetProp<public>() : ?creative_prop_asset =
        false
