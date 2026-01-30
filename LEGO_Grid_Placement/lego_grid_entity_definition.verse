using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# ============================================================================================================================================
# This class is the base class for all grid entities that can be placed on the grid
# It is used to define the properties of the entity, such as its dimensions, name, and unlock category
# ============================================================================================================================================

Tooltip_GridEntity_Name<public><localizes> : message = "The name of the grid entity."
Tooltip_GridEntity_PropAsset<public><localizes> : message = "The prop asset that represents the grid entity."
Tooltip_GridEntity_UnlockCategory<public><localizes> : message = "The category of the unlock pack that unlocks this grid entity."
Tooltip_GridEntity_SoloPropDefinition<public><localizes> : message = "The definition of the solo prop that represents this grid entity."
Tooltip_GridEntity_ObjectDefinition<public><localizes> : message = "The definition of the object that represents this grid entity."
Tooltip_GridEntity_HeightInPlates<public><localizes> : message = "The height in plates used for both objects and solo props."

lego_grid_entity_definition<public> := class<concrete><unique>(lego_convertible_dimensions_interface, lego_initializable_interface):
    @editable:
        ToolTip := Tooltip_GridEntity_Name
    Name : string = ""

    @editable:
        ToolTip := Tooltip_GridEntity_PropAsset
    PropAsset : creative_prop_asset = DefaultCreativePropAsset

    @editable:
        ToolTip := Tooltip_GridEntity_HeightInPlates
    Height_InPlates : int = 10

    @editable:
        ToolTip := Tooltip_GridEntity_SoloPropDefinition
    SoloPropDefinition : ?lego_grid_plot_definition_soloprop = false
    
    @editable:
        ToolTip := Tooltip_GridEntity_ObjectDefinition
    ObjectDefinition : ?lego_grid_object_definition = false

    @editable:
        ToolTip := Tooltip_GridEntity_UnlockCategory
    UnlockCategory : en_lego_grid_unlockpack_categories = en_lego_grid_unlockpack_categories.AlwaysUnlocked

    var EntityID<public> : int = 0

    ConvertDimensions<override>() : void =
        if (ValidObjectDefinition := ObjectDefinition?):
            ValidObjectDefinition.ConvertDimensions()
            set ValidObjectDefinition.Height = GetCmFromPlates(Height_InPlates)

        if (ValidSoloProp := SoloPropDefinition?):
            ValidSoloProp.ConvertDimensions()
            set ValidSoloProp.CellZSize = GetCmFromPlates(Height_InPlates)


        

    Initialize<override>() : void =
        ConvertDimensions()

        if (ValidObjectDefinition := ObjectDefinition?):
            set ValidObjectDefinition.PropAsset = PropAsset
            set ValidObjectDefinition.EntityID = EntityID
            ValidObjectDefinition.SetName(Name)

        if (ValidSoloPropDefinition := SoloPropDefinition?):
            set ValidSoloPropDefinition.PropAsset = option{PropAsset}
            set ValidSoloPropDefinition.EntityID = EntityID
            ValidSoloPropDefinition.SetName(Name)
            
            if (ValidObjectDefinition := ObjectDefinition?):
                set ValidSoloPropDefinition.ObjectDefinition = option{ValidObjectDefinition}