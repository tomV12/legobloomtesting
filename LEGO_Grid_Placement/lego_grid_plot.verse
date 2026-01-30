using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Colors }
using { /Fortnite.com/Devices }

using { LEGOUtilities }

# ============================================================================================================================================
# Represents a plot of cells in the grid
# ============================================================================================================================================

Tooltip_GridPlot_Layers<public><localizes> : message = "The number of layers in the grid plot."

lego_grid_plot_definition<public> := class<abstract>(lego_grid_size_interface, lego_convertible_dimensions_interface, lego_grid_prop_interface, lego_grid_plot_factory_interface, lego_grid_plot_interface, lego_nameable_interface, lego_initializable_interface):
    var OwnerUUID : int = 0
    var Name : string = ""

    CenterLocation<public> : vector3 = vector3{}
    var Rotation<public> : rotation = IdentityRotation()

lego_grid_plot<public> := class<abstract><unique>(lego_grid_size_interface, lego_initializable_interface):
    Columns<public> : int = 1
    Rows<public> : int = 1
    Layers<public> : int = 1
    GridCellSize<public> : float = 0.0
    Category<public> : en_lego_grid_plot_category = en_lego_grid_plot_category.Default

    var CenterLocation<public> : vector3 = vector3{}
    var Rotation<public> : rotation = IdentityRotation()
    var Location<public> : vector3 = vector3{}
    
    var OwnerUUID : int = 0    
    var GridObjects<public> : [][][]?lego_grid_object_base = array{array{array{}}}
    var ValidGridObjects<public> : [int]lego_grid_object_data = map{}

    Logger<protected> : log = log{Channel := lego_grid_persistence_log, DefaultLevel := log_level.Normal}


    # ----------------------------------------------------------------------------------------------------------------------------------------
    # GridObject Management
    # ----------------------------------------------------------------------------------------------------------------------------------------

    # It is assumed that Columns, Rows and Layer values are not >1000, otherwise the hash will exceed MAX_INT
    GetGridObjectHash<public>(InGridObjectData : lego_grid_object_data)<transacts> : int =
        return InGridObjectData.Row * 1001 * 1001 + InGridObjectData.Column * 1001 + InGridObjectData.Layer

    # Whenever a GridObject is added, this function is invoked
    AddValidGridObject(InGridObjectData : lego_grid_object_data)<transacts> : void =
        if (set ValidGridObjects[GetGridObjectHash(InGridObjectData)] = InGridObjectData)
        {}
        else:
            Logger.Print("AddValidGridObject failed.", ?Level := log_level.Error)

    # Whenever a GridObject is removed, this function is invoked
    RemoveValidGridObject(InGridObjectData : lego_grid_object_data)<transacts> : void =
        var NewMap : [int]lego_grid_object_data = map{}
        for (Key -> Value : ValidGridObjects):
            if (Key <> GetGridObjectHash(InGridObjectData)):
                set NewMap = ConcatenateMaps(NewMap, map{Key => Value})
        set ValidGridObjects = NewMap

    # Delete all objects in the plot
    ClearAllPlotObjects<public>()<suspends> : void =
        var Index : int = 0
        for (Hash -> GridData : ValidGridObjects):
            set Index += 1
            if:
                TargetObject := GridObjects[GridData.Row][GridData.Column][GridData.Layer]?
                Prop := TargetObject.Prop?
            then:
                Prop.Hide()
                Prop.Dispose()
                if (set GridObjects[GridData.Row][GridData.Column][GridData.Layer] = false)
                {}

            # Sleep to avoid server stall
            if (Mod[Index, 50] = 0):
                Sleep(0.1)

        set ValidGridObjects = map{}


    # Load all objects from the data
    LoadPlotObjectsFromData<public>(InDevice : creative_device, InData : lego_grid_plot_persistent_data)<suspends> : void =
        if (InData.BitpackedGridObjects.Length = 0):
            Logger.Print("Plot: No Objects to Load", ?Level := log_level.Warning)
            return

        Logger.Print("Plot: Loading and placing {InData.BitpackedGridObjects.Length} Objects from Data")
        for (Index -> BitpackedGridObjectData : InData.BitpackedGridObjects):            
            # Sleep to avoid server stall
            if (Mod[Index, 50] = 0):
                Sleep(0.1)

            GridObjectData := BitpackedGridObjectData.UnpackGridObjectData()
            # Try to retrieve the EntityDefinition from the GridEntityManager and place the object
            if: 
                GridDevice := GetLEGOGridDevice[InDevice]
                GridEntityManager := GridDevice.EntityManager
                ValidEntityDefinition := GridEntityManager.GridEntityDefinitions[GridObjectData.EntityID]
            then:
                PlaceGridObject(ValidEntityDefinition, MakeRotationFromYawPitchRollDegrees(Roll := 0.0, Pitch := 0.0, Yaw := GridObjectData.Rotation), GridObjectData.Row, GridObjectData.Column, GridObjectData.Layer, GridDevice)
            else:
                Logger.Print("Error: Could not find EntityDefinition at index {GridObjectData.EntityID}", ?Level := log_level.Error)


    GetGridObject<public>(Coordinate : tuple(int, int, int), Layer : int)<transacts> : ?lego_grid_object_base =   
        if (ValidObject := GridObjects[Coordinate(0)][Coordinate(1)][Layer]?):
            option{ValidObject}
        else:
            false


    PlaceGridObject<public>(EntityDefinition : lego_grid_entity_definition, InRotation : rotation, Row : int, Column : int, Layer : int, InGridDevice : lego_grid_device) : void =
        var ObjectZ : float = 0.0

        if (ObjectBelow := GridObjects[Row][Column][Layer-1]?):
            set ObjectZ = ObjectBelow.Location.Z + ObjectBelow.Height
        else:
            set ObjectZ = Location.Z + (GridCellSize * Layer)
        
        if (ObjectDefinition := EntityDefinition.ObjectDefinition?):
            ObjectLocation := vector3:
                X := Location.X + Row * GridCellSize + GridCellSize * 0.5
                Y := Location.Y + Column * GridCellSize + GridCellSize * 0.5
                Z := ObjectZ

            NewObject := ObjectDefinition.CreateObject(ObjectDefinition, ObjectLocation, InRotation)
            if:
                ValidProp := NewObject.Prop?
                InGridDevice.PropsCanBeDamaged = false
            then:
                set ValidProp.CanBeDamaged = false
            

            if:
                not GridObjects[Row][Column][Layer]?
                set GridObjects[Row][Column][Layer] = option{NewObject}

                GridObjectData := lego_grid_object_data:
                    Row := Row
                    Column := Column
                    Layer := Layer
                    Rotation := InRotation.GetYawPitchRollDegrees()[0]
                    EntityID := ObjectDefinition.EntityID

                AddValidGridObject(GridObjectData)
                

    # ----------------------------------------------------------------------------------------------------------------------------------------
    # Placement and Removal
    # ----------------------------------------------------------------------------------------------------------------------------------------
    PlaceGridObject_Direct<public>(EntityDefinition : lego_grid_entity_definition, InRotation : rotation, Row : int, Column : int, Layer : int, InGridDevice : lego_grid_device) : void =
        var ObjectZ : float = Location.Z + GridCellSize * Layer
        
        if (ObjectDefinition := EntityDefinition.ObjectDefinition?):
            ObjectLocation : vector3 = vector3:
                X := Location.X + Row * GridCellSize + GridCellSize * 0.5
                Y := Location.Y + Column * GridCellSize + GridCellSize * 0.5
                Z := ObjectZ

            NewObject := ObjectDefinition.CreateObject(ObjectDefinition, ObjectLocation, InRotation)
            if:
                ValidProp := NewObject.Prop?
                InGridDevice.PropsCanBeDamaged = false
            then:
                set ValidProp.CanBeDamaged = false

            if:
                not GridObjects[Row][Column][Layer]?
                set GridObjects[Row][Column][Layer] = option{NewObject}

                GridObjectData := lego_grid_object_data:
                    Row := Row
                    Column := Column
                    Layer := Layer
                    Rotation := InRotation.GetYawPitchRollDegrees()[0]
                    EntityID := ObjectDefinition.EntityID

                AddValidGridObject(GridObjectData)


    DeleteGridObject<public>(Row : int, Column : int, Layer : int) : void =
        if:
            TargetObject := GridObjects[Row][Column][Layer]?
            Prop := TargetObject.Prop?
        then:
            Prop.Dispose()
            if (set GridObjects[Row][Column][Layer] = false) {}

            GridObjectData := lego_grid_object_data:
                Row := Row
                Column := Column
                Layer := Layer

            RemoveValidGridObject(GridObjectData)


    DeleteGridObject_Direct<public>(Row : int, Column : int, Layer : int) : void =    
        if:
            TargetObject := GridObjects[Row][Column][Layer]?
            Prop := TargetObject.Prop?
        then:
            Prop.Dispose()
            if (set GridObjects[Row][Column][Layer] = false) {}

            GridObjectData := lego_grid_object_data:
                Row := Row
                Column := Column
                Layer := Layer

            RemoveValidGridObject(GridObjectData)


    SetGridObject<public>(EntityDefinition : lego_grid_entity_definition, Row : int, Column : int, Layer : int) : void =
        var ObjectZ : float = 0.0

        if (ObjectBelow := GridObjects[Row][Column][Layer-1]?):
            set ObjectZ = ObjectBelow.Location.Z + ObjectBelow.Height
        else:
            set ObjectZ = Location.Z
        
        if (ObjectDefinition := EntityDefinition.ObjectDefinition?):
            ObjectLocation : vector3 = vector3:
                X := Location.X + Row * GridCellSize + GridCellSize * 0.5
                Y := Location.Y + Column * GridCellSize + GridCellSize * 0.5
                Z := ObjectZ

            NewObject : lego_grid_object_base = ObjectDefinition.CreateObject(ObjectDefinition, ObjectLocation, IdentityRotation())
            
            if:
                set GridObjects[Row][Column][Layer] = option{NewObject}
            then:
                NewObject.SpawnProp()

                GridObjectData := lego_grid_object_data:
                    Row := Row
                    Column := Column
                    Layer := Layer
                    EntityID := ObjectDefinition.EntityID

                AddValidGridObject(GridObjectData)

                
    DrawPlot<public>(PlotPreview : creative_prop_asset) : void =
        Scale : vector3 = vector3:
            X := Rows * GetCellXSize() / 100.0
            Y := Columns * GetCellYSize() / 100.0
            Z := 1.0
            
        SpawnProp(PlotPreview, transform{Translation := CenterLocation, Rotation := Rotation, Scale := Scale})
        Logger.Print("Attempted DrawPlot with {Rows} rows and {Columns} columns and grid cell size {GridCellSize} at position {Location}")


    Delete<public>()<suspends> : void =        
        for (RowIndex := 0..Rows - 1):
            Sleep(0.0)
            for (ColumnIndex := 0..Columns - 1):
                Sleep(0.0)
                for (LayerIndex := 0..Layers - 1):
                    Sleep(0.0)
                    DeleteGridObject(RowIndex, ColumnIndex, LayerIndex)


Make3DArray<public>(Rows : int, Columns : int, Layers : int)<suspends> : [][][]?lego_grid_object_base =    
    var Objects : [][][]?lego_grid_object_base = array{}
    set Objects =
        for (Row := 0..Rows - 1):
            for (Column := 0..Columns - 1):
                for (Layer := 0..Layers - 1):
                    false
