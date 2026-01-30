using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Simulation }
using { /Verse.org/Colors/NamedColors }
using { /Fortnite.com/Devices }

using { LEGOUtilities }

# ========================================================================================================================================
# All the types used for saving and loading persistent data for the LEGO Grid Placement system
# ========================================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------------------------
# Data structure that is saved to the player's persistent data
# ----------------------------------------------------------------------------------------------------------------------------------------
lego_fortplayer_persistence_data<public> := class<persistable><final>:
    UUID<public> : int = 0
    UnlockedAssets<public> : []int = array{}
    Plots<public> : []lego_grid_plot_persistent_data = array{}

(InData: lego_fortplayer_persistence_data).Serialize<public>() : string =
    var OutString : string = ""
    set OutString += "Total Plots : {InData.Plots.Length} --- "
    
    var SoloPlotCount : int = 0
    for (Index -> PlotData : InData.Plots):
        case (PlotData.PlotType):
            EN_GridPlotPlotType.Cells =>
                set OutString += "[GridPlot {Index}: {PlotData.Serialize()}] "
            EN_GridPlotPlotType.SoloProp =>
                set SoloPlotCount += 1

    set OutString += "[Total SoloProps: {SoloPlotCount}] "
    return OutString
    
# ----------------------------------------------------------------------------------------------------------------------------------------
# Grid Plot
# ----------------------------------------------------------------------------------------------------------------------------------------
EN_GridPlotPlotType<public> := enum<persistable> { Cells, SoloProp }
lego_grid_plot_persistent_data<public> := class<persistable><final>:
    OwnerUUID<public> : int = 0

    PlotType<public> : EN_GridPlotPlotType = EN_GridPlotPlotType.Cells
    PlotCategory<public> : en_lego_grid_plot_category = en_lego_grid_plot_category.Default

    Columns<public> : int = 1
    Rows<public> : int = 1
    Layers<public> : int = 1
    GridCellSize<public> : float = 0.0

    Rotation<public> : float = 0.0
    Location<public> : vector3 = vector3{X := 0.0, Y := 0.0, Z := 0.0}

    # This is a version of the grid object data compressed into a single int to reduce the size of the data
    BitpackedGridObjects<public> : []tuple(int, int) = array{}


# Convert a LEGO_grid_plot to a LEGO_grid_plot_persistent_data PlotType
(InGridPlot : lego_grid_plot).ToPersistentGridPlot(InDevice : creative_device, InUUID : int, InOffset : vector3)<suspends> : lego_grid_plot_persistent_data =
    Logger: log = log{Channel := lego_grid_persistence_log, DefaultLevel := log_level.Normal}

    # Determine the PlotType of plot
    var PlotType : EN_GridPlotPlotType = EN_GridPlotPlotType.Cells
    
    if (lego_grid_plot_cells[InGridPlot]):
        set PlotType = EN_GridPlotPlotType.Cells

    if (lego_grid_plot_soloprop[InGridPlot]):
        set PlotType = EN_GridPlotPlotType.SoloProp
    
    # Create the <persistable> version of GridObject
    var PersistenctGridObjects : []tuple(tuple(int, int, int), float, int) = array{}
    var BitpackedGridObjectsBuffer : []tuple(int, int) = array{}

    if (GridDevice := GetLEGOGridDevice[InDevice]):
        var Index : int = 0

        # Save all valid grid objects
        for (ValidGridObject : InGridPlot.ValidGridObjects):
            var EntityID : int = ValidGridObject.EntityID
            GridObjectData := lego_grid_object_data:
                Row := ValidGridObject.Row
                Column := ValidGridObject.Column
                Layer := ValidGridObject.Layer
                Rotation := ValidGridObject.Rotation
                EntityID := EntityID

            set BitpackedGridObjectsBuffer += array{GridObjectData.PackGridObjectData()}

            # Sleep every 25 objects to avoid server stall
            set Index += 1
            if (Mod[Index, 25] = 0):
                Sleep(0.1)
    else:
        Logger.Print("ERROR - Could not get GridDevice", ?Level := log_level.Error)

    var PlotRotation : float = 0.0
    if (ValidPlotRotation := InGridPlot.Rotation.GetYawPitchRollDegrees()[0]):
        set PlotRotation = ValidPlotRotation

    OutData := lego_grid_plot_persistent_data:
        OwnerUUID := InUUID
        PlotType := PlotType
        PlotCategory := InGridPlot.Category
        Columns := InGridPlot.Columns
        Rows := InGridPlot.Rows
        Layers := InGridPlot.Layers
        GridCellSize := InGridPlot.GridCellSize
        Location := InGridPlot.Location - InOffset
        Rotation := PlotRotation
        BitpackedGridObjects := BitpackedGridObjectsBuffer
    return OutData

# Serialize the persistent data for debugging
(InData: lego_grid_plot_persistent_data).Serialize<public>() : string =
    var Result : string = ""
    case (InData.PlotType):
        EN_GridPlotPlotType.Cells =>
            set Result = "[GridPlot (Cells) - GridObject Count: {InData.BitpackedGridObjects.Length}] "
        EN_GridPlotPlotType.SoloProp =>
            set Result = "[SoloProp] "
    return Result


# ----------------------------------------------------------------------------------------------------------------------------------------
# Grid Object - used for conversion of non <persistable> data to <persistable> data - also provdides Bitpacking functions
# ----------------------------------------------------------------------------------------------------------------------------------------
lego_grid_object_data<public> := struct:
    Row<public> : int = 0
    Column<public> : int = 0
    Layer<public> : int = 0
    Rotation<public> : float = 0.0
    EntityID<public> : int = 0

# Compress the struct to a packed int
(InGridObjectData : lego_grid_object_data).PackGridObjectData()<transacts> : tuple(int, int) =
    # Use smaller powers and appropriate scaling to avoid floating point precision issues
    # Row (14 bits), Column (14 bits), Layer (14 bits), Rotation (8 bits)

    if:
        # Ensure values are within valid ranges
        ValidRow := Max(0, Min(16383, InGridObjectData.Row))  # 2^14-1
        ValidColumn := Max(0, Min(16383, InGridObjectData.Column))
        ValidLayer := Max(0, Min(16383, InGridObjectData.Layer))

        # Scale rotation to 0-255 range
        NormalizedRotation := Mod[Floor[InGridObjectData.Rotation], 360]
        RotationValue := Floor[Max(0.0, Min(255.0, ((NormalizedRotation * 1.0) / 360.0) * 255.0))]        
        
        # Pack values using multiplication and addition
        PackedGridObjectData := ((ValidRow * 16384 + ValidColumn) * 16384 + ValidLayer) * 256 + Floor(RotationValue)
    then:
        return (PackedGridObjectData, InGridObjectData.EntityID)
    else:
        return (0, 0)

# Decompress the packed int to a grid object data struct
(InPackedGridObjectData : tuple(int, int)).UnpackGridObjectData()<transacts> : lego_grid_object_data =
    if:
        # Extract values in reverse order of packing
        var Buffer : float = InPackedGridObjectData(0) * 1.0
        
        # Extract Rotation (lowest 8 bits)
        RotationInt : int = Mod[Floor[Buffer], 256]
        set Buffer = Buffer / 256.0
        
        # Extract Layer (next 14 bits)
        UnpackedLayer : int = Mod[Floor[Buffer], 16384]
        set Buffer = Buffer / 16384.0
        
        # Extract Column (next 14 bits)
        UnpackedColumn : int = Mod[Floor[Buffer], 16384]
        set Buffer = Buffer / 16384.0
        
        # Extract Row (remaining bits)
        UnpackedRow : int = Floor[Buffer]
        
        # Convert rotation back to degrees
        UnpackedRotation : float = (RotationInt * 360.0) / 256.0
        
        OutData : lego_grid_object_data = lego_grid_object_data:
            Row := UnpackedRow
            Column := UnpackedColumn
            Layer := UnpackedLayer
            Rotation := UnpackedRotation
            EntityID := InPackedGridObjectData(1)
    then:
        return OutData
    else:
        DebugPrint("ERROR - Could not unpack GridObjectData", ?Color := Red)
        return lego_grid_object_data{}