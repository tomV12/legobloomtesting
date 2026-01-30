using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Colors }
using { /Fortnite.com/Devices }
using { /Verse.org/Assets }

using { LEGOUtilities }

# ============================================================================================================================================
# Represents a plot of that only has a single object in it
# ============================================================================================================================================
Tooltip_GridPlot_Solo_CellXSize<public><localizes> : message = "The size of the grid cell in studs."
Tooltip_GridPlot_Solo_CellYSize<public><localizes> : message = "The size of the grid cell in studs."
Tooltip_GridPlot_Solo_CellZSize<public><localizes> : message = "The size of the grid cell in studs."

# Create a plot from a definition of a solo prop plot and a preview of the plot to create the plot
CreateSoloPropFromDefinition<constructor><public>(PlotPreview : lego_grid_plot_preview, PlotDefinition : lego_grid_plot_definition_soloprop, PlotLocation : vector3, PlotRotation : rotation) := lego_grid_plot_soloprop:
    OwnerUUID := PlotDefinition.OwnerUUID
    Columns := PlotPreview.Columns
    Rows := PlotPreview.Rows
    Layers := PlotDefinition.Layers
    GridCellSize := PlotPreview.GridCellSize
    CellXSize := PlotPreview.CellXSize
    CellYSize := PlotPreview.CellYSize

    Location := PlotLocation
    CenterLocation := vector3:
        X := PlotLocation.X + PlotPreview.Rows * PlotPreview.CellXSize * 0.5
        Y := PlotLocation.Y + PlotPreview.Columns * PlotPreview.CellYSize * 0.5
        Z := PlotLocation.Z
    Rotation := PlotPreview.Rotation
    
    let:
        var Objects : [][][]?lego_grid_object_base = array{array{array{}}}
        var TempPropAsset : ?creative_prop_asset = false
        var TempObjectDefinition : ?lego_grid_object_definition = false
    block:
        set Objects =
            for (Row := 0..0):
                for (Column := 0..0):
                    for (Layer := 0..0):
                        false

        if:
            ValidObjectDefinition := PlotDefinition.ObjectDefinition?
        then:
            set TempObjectDefinition = option{ValidObjectDefinition}

    PropAsset := TempPropAsset
    ObjectDefinition := TempObjectDefinition
    GridObjects := Objects

# Create a plot from a only definition of a solo prop plot to create the plot
CreateSoloPropFromDefinition<constructor><public>(PlotDefinition : lego_grid_plot_definition_soloprop, PlotLocation : vector3, PlotRotation : rotation) := lego_grid_plot_soloprop:
    OwnerUUID := PlotDefinition.OwnerUUID
    Columns := 1
    Rows := 1
    Layers := PlotDefinition.Layers
    GridCellSize := PlotDefinition.CellXSize
    CellXSize := PlotDefinition.CellXSize
    CellYSize := PlotDefinition.CellYSize

    Location := PlotLocation
    CenterLocation := vector3:
        X := PlotLocation.X + 1 * PlotDefinition.CellXSize * 0.5
        Y := PlotLocation.Y + 1 * PlotDefinition.CellYSize * 0.5
        Z := PlotLocation.Z
    Rotation := PlotRotation

    let:
        var Objects : [][][]?lego_grid_object_base = array{array{array{}}}
        var TempPropAsset : ?creative_prop_asset = false
        var TempObjectDefinition : ?lego_grid_object_definition = false
    block:
        set Objects =
            for (Row := 0..0):
                for (Column := 0..0):
                    for (Layer := 0..0):
                        false

        if:
            ValidObjectDefinition := PlotDefinition.ObjectDefinition?
        then:
            set TempObjectDefinition = option{ValidObjectDefinition}

    PropAsset := TempPropAsset
    ObjectDefinition := TempObjectDefinition
    GridObjects := Objects


# ============================================================================================================================================
# Represents a plot of that only has a single object in it
# ============================================================================================================================================
lego_grid_plot_definition_soloprop<public> := class<concrete><unique>(lego_grid_plot_definition):
    var ObjectDefinition : ?lego_grid_object_definition = false
    var PropAsset : ?creative_prop_asset = option{DefaultCreativePropAsset}

    var CellXSize : float = 0.0 
    var CellYSize : float = 0.0
    var CellZSize : float = 0.0

    var EntityID : int = 0

    Layers<public> : int = 1

    @editable:
        ToolTip := Tooltip_GridPlot_Solo_CellXSize
    CellXSize_InStuds: int = 1

    @editable:
        ToolTip := Tooltip_GridPlot_Solo_CellYSize
    CellYSize_InStuds: int = 1

    GetCellXSize<override>()<transacts> : float =
        CellXSize

    GetCellYSize<override>()<transacts> : float =
        CellYSize

    GetCellZSize<override>()<transacts> : float =
        CellZSize

    GetGridCellSize<override>()<transacts> : float =
        CellXSize

    CreatePlot<override>(PlotPreview : lego_grid_plot_preview, Location : vector3, PlacementRotation : rotation) : lego_grid_plot = 
        CreateSoloPropFromDefinition(PlotPreview, Self, Location, PlacementRotation)

    CreatePlot<override>(Location : vector3, PlacementRotation : rotation) : lego_grid_plot = 
        CreateSoloPropFromDefinition(Self, Location, PlacementRotation)

    ConvertDimensions<override>() : void =
        set CellXSize = GetCmFromStuds(CellXSize_InStuds)
        set CellYSize = GetCmFromStuds(CellYSize_InStuds)

    GetProp<override>()<transacts> : ?creative_prop_asset =
        PropAsset

    GetColumns<override>()<transacts> : int =
        1

    GetRows<override>()<transacts> : int =
        1

    GetName<override>() : string =
        Name

    SetName<override>(NewName : string) : void =
        set Name = NewName

    Initialize<override>() : void =
        ConvertDimensions()

lego_grid_plot_soloprop<public> := class<concrete><unique>(lego_grid_plot): 
    var PropAsset : ?creative_prop_asset = false
    var ObjectDefinition<public> : ?lego_grid_object_definition = false
    Category<override> : en_lego_grid_plot_category = en_lego_grid_plot_category.SoloProp

    var CreatedObject : ?lego_grid_object_base = false

    CellXSize<public> : float = 0.0
    CellYSize<public> : float = 0.0
    CellZSize<public> : float = 0.0

    Initialize<override>() : void =
        if:
            ValidObjectDefinition := ObjectDefinition?
        then:
            Object := ValidObjectDefinition.CreateObject(ValidObjectDefinition, CenterLocation, Rotation)
            set CreatedObject = option{Object}
            GridObjectData := lego_grid_object_data:
                EntityID := ValidObjectDefinition.EntityID
            AddValidGridObject(GridObjectData)

            if:
                set GridObjects[0][0][0] = option{Object}
            then:
                Object.Initialize()

    GetCellXSize<override>()<transacts> : float =
        CellXSize

    GetCellYSize<override>()<transacts> : float =
        CellYSize

    GetCellZSize<override>()<transacts> : float =
        CellZSize

    GetGridCellSize<override>()<transacts> : float =
        CellZSize

    DrawPlot<override>(PlotPreview :creative_prop_asset) : void = {}

    Delete<override>() : void =
        if (ValidSpawnedProp := CreatedObject?.Prop?):
            ValidSpawnedProp.Hide()
            ValidSpawnedProp.Dispose()

        set CreatedObject = false
    
        if (ValidGidObjectData := ValidGridObjects[0]):
            RemoveValidGridObject(ValidGidObjectData)
