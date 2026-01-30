using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Assets }

using { LEGOUtilities }

# ============================================================================================================================================
# This file contains the definition of a grid object, which is a placeable object in the grid
# ============================================================================================================================================
Types<public> := enum{Default, Soil, Plant, Grounded, Connected}

Tooltip_GridObject_Name<public><localizes> : message = "The name of the grid object."
Tooltip_GridObject_Category<public><localizes> : message = "The category of the grid object."
Tooltip_GridObject_PropAsset<public><localizes> : message = "The prop asset that represents the grid object."
Tooltip_GridObject_GridCellSizeInStuds<public><localizes> : message = "The size of the grid cell in studs."
Tooltip_GridObject_CanBuildUpon<public><localizes> : message = "Whether the object can be built upon."
Tooltip_GridObject_Type<public><localizes> : message = "The type of the grid object."
Tooltip_GridObject_Texture<public><localizes> : message = "The texture of the grid object."

lego_grid_object_definition<public> := class<abstract>(lego_convertible_dimensions_interface, lego_grid_size_interface, lego_nameable_interface, lego_grid_object_factory_interface):
    var Name : string = ""

    @editable:
        ToolTip := Tooltip_GridObject_Category
    Category : string = ""

    var PropAsset : creative_prop_asset = DefaultCreativePropAsset
    var Height : float = 0.0
    
    @editable:
        ToolTip := Tooltip_GridObject_GridCellSizeInStuds
    var GridCellSize_InStuds : int = 4
    var GridCellSize : float = 0.0

    @editable:
        ToolTip := Tooltip_GridObject_CanBuildUpon
    CanBuildUpon : logic = true

    @editable:
        ToolTip := Tooltip_GridObject_Type
    Type : Types = Types.Default

    @editable:
        ToolTip := Tooltip_GridObject_Texture
    Texture : texture = LEGO_Grid_Placement.Icons.T_FallbackTexture

    # This value is initialized by the EntityManager OnBegin() and represents the index of the object in the list of objects
    var EntityID : int = -1

    GetName<override>() : string =
        Name

    SetName<override>(NewName : string) : void =
        set Name = NewName

    ConvertDimensions<override>() : void =
        set GridCellSize = GetCmFromStuds(GridCellSize_InStuds)

    GetCellXSize<override>()<transacts> : float =
        GridCellSize

    GetCellYSize<override>()<transacts> : float =
        GridCellSize

    GetCellZSize<override>()<transacts> : float =
        GridCellSize

    GetGridCellSize<override>()<transacts> : float =
        GridCellSize

LEGO_grid_object_definition_base<public> := class<concrete>(lego_grid_object_definition):
    CreateObject<override>(ObjectDefinition : lego_grid_object_definition, ObjectLocation : vector3, ObjectRotation : rotation): lego_grid_object_base =
        Object := MakeObjectFromDefinition(ObjectDefinition, ObjectLocation, ObjectRotation)
        Object.Initialize()
        Object
    
lego_grid_object_base<public> := class<concrete>(lego_initializable_interface):
    var Prop : ?creative_prop = false
    var Location : vector3 = vector3{}
    var Rotation : rotation = rotation{}
    Category : string = ""
    PropAsset : creative_prop_asset = DefaultCreativePropAsset
    var Height : float = 0.0
    CanBuildUpon : logic = true
    Type : Types = Types.Grounded

    Initialize<override>() : void = 
        SpawnProp()

    SpawnProp() : void =
        if (ValidProp := Prop?):
            return
        
        DebugLog("GridObject: Spawning prop from category {Category} at {Location}")
        SpawnedProp := SpawnProp(PropAsset, Location, Rotation)
        PropInstance := SpawnedProp(0)
        set Prop = PropInstance

MakeObjectFromDefinition<constructor><public>(ObjectDefinition : lego_grid_object_definition, ObjectLocation : vector3, ObjectRotation : rotation) := lego_grid_object_base:
    Location := ObjectLocation
    Rotation := ObjectRotation
    Category := ObjectDefinition.Category
    PropAsset := ObjectDefinition.PropAsset
    Height := ObjectDefinition.Height
    CanBuildUpon := ObjectDefinition.CanBuildUpon
    Type := ObjectDefinition.Type

MakeObjectFromDefinition_WithPreview<constructor><public>(ObjectPreview : lego_grid_object_preview, ObjectDefinition : LEGO_grid_object_definition_base, ObjectLocation : vector3) := lego_grid_object_base:
    Location := ObjectLocation
    Rotation := ObjectPreview.Rotation
    Category := ObjectDefinition.Category
    PropAsset := ObjectDefinition.PropAsset
    Height := ObjectDefinition.Height
    CanBuildUpon := ObjectDefinition.CanBuildUpon
    Type := ObjectDefinition.Type