using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }

# ========================================================================================================================================
# Represents a preview of a plot in the world, used to preview the placement of a grid object
# ========================================================================================================================================

lego_grid_plot_preview<public> := class:
    var ObjectDefinition<public> : ?lego_grid_object_definition = false    
    var PropAsset<public> : ?creative_prop_asset = false    
    var Rows : int = 0
    var Columns : int = 0
    var Layers : int = 0
    var GridCellSize : float = 0.0
    var CellXSize : float = 0.0
    var CellYSize : float = 0.0
    var CellZSize : float = 0.0
    var Rotation_90 : int = 0
    var Rotation : rotation = IdentityRotation()
    var Height : float = 0.0

    UpdateRotation(InRotation_90 : int) : void =
        if (OutRotation_90 :=  Mod[Rotation_90 + InRotation_90, 4]):
            set Rotation_90 = OutRotation_90
            set Rotation = Rotation.ApplyYaw(InRotation_90 * 90.0)

    GetPropAsset<public>() : ?creative_prop_asset =
        PropAsset

    SetPropAsset<public>(Asset : ?creative_prop_asset) : void = 
        set PropAsset = Asset

    GetObjectDefinition<public>() : ?lego_grid_object_definition =
        ObjectDefinition

    SetObjectDefinition<public>(InObjectDefinition : ?lego_grid_object_definition) : void = 
        set ObjectDefinition = InObjectDefinition


GetCoordinateInPlot<public>(InLocation : vector3, Plot : lego_grid_plot)<decides><transacts> : tuple(int, int, int) =
        var OutCoordinates : ?tuple(int, int, int) = false
        RootX : float = Plot.Location.X
        RootY : float = Plot.Location.Y
        RootZ : float = Plot.Location.Z
        GridCellSize: float = Plot.GridCellSize

        if:
            X : float = (InLocation.X - RootX) / GridCellSize
            Y : float = (InLocation.Y - RootY) / GridCellSize
            Z := Max((InLocation.Z - RootZ) / GridCellSize, 0.0)
            Coordinates : tuple(int, int, int) = (Floor[X], Floor[Y], Floor[Z])
        then:            
            set OutCoordinates = option{Coordinates}

        OutCoordinates?

        
# ========================================================================================================================================
# Represents a preview of a grid object in a grid, used to preview the placement of a grid object
# ========================================================================================================================================

lego_grid_object_preview<public> := class:
    var Location : vector3 = vector3{}
    var Name : string = ""
    var Category : string = ""
    var PropAsset : creative_prop_asset = DefaultCreativePropAsset
    var Height : float = 0.0
    var CanBuildUpon : logic = false
    var Rotation_90 : int = 0
    var Rotation : rotation = IdentityRotation()

    UpdateRotation(InRotation_90 : int) : void =
        if (OutRotation_90 :=  Mod[Rotation_90 + InRotation_90, 4]):
            set Rotation_90 = OutRotation_90
            set Rotation = Rotation.ApplyYaw(InRotation_90 * 90.0)

    GetPropAsset<public>() : creative_prop_asset =
        PropAsset

    SetPropAsset<public>(Asset : creative_prop_asset) : void = 
        set PropAsset = Asset
