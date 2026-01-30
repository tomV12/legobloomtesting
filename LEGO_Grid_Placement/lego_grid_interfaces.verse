using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Simulation }

# ============================================================================================================================================
# A unified location for all interfaces that are implemented by the classes in the grid placement system
# ============================================================================================================================================

# Used in any class that needs to convert from LEGO Studs for width/length and Plates for height to Unreal Units/cm (lego_grid_entity, lego_grid_object, lego_grid_plot and any inheritors of these)
lego_convertible_dimensions_interface<public> := interface():
    ConvertDimensions<public>() : void

# Used to get dimensions in any class instance or class instance creator (aka factory) that has grid cells or can be placed in a grid cell (lego_grid_plot, lego_grid_plot_definition, lego_grid_object_definition and any inheritors)
lego_grid_size_interface<public> := interface():
    GetGridCellSize()<transacts> : float
    GetCellXSize<public>()<transacts> : float
    GetCellYSize<public>()<transacts> : float
    GetCellZSize<public>()<transacts> : float

# Used in any grid plot definition class to create instances of that class in a standardized way (lego_grid_plot_definition)
lego_grid_plot_factory_interface<public> := interface():
    CreatePlot<public>(PlotPreview : lego_grid_plot_preview, Location : vector3, PlacementRotation:rotation) : lego_grid_plot
    CreatePlot<public>(Location : vector3, PlacementRotation : rotation) : lego_grid_plot

# Used in any grid object definition class to create instances of that class in a standardized way (lego_grid_object_definition)
lego_grid_object_factory_interface<public> := interface():
    CreateObject<public>(ObjectDefinition : lego_grid_object_definition, ObjectLocation : vector3, ObjectRotation : rotation) : lego_grid_object_base

lego_grid_prop_interface<public> := interface():
    GetProp()<transacts> : ?creative_prop_asset

# Used in any plot definition class to get the number of columns or rows (lego_grid_plot_definition)
lego_grid_plot_interface<public> := interface():
    GetColumns()<transacts> : int
    GetRows()<transacts> : int

# Used in any class that needs to be initialized, usually OnBegin() or when a new class instance is created. Usually contains other functions that need to run for the system to work, ConvertDimensions() for example to get Unreal Units from LEGO Units.
# Can have a high up-front cost and need be called once on game start or on class instantiation (lego_grid_plot, lego_grid_plot_definition, lego_grid_entity, lego_grid_object, lego_grid_unlock_pack, lego_grid_nobuildzone and any inheritors)
lego_initializable_interface<public> := interface():
    Initialize()<suspends> : void

# Used for any class that has a name to provide a standardized way of getting and setting its name (lego_grid_plot_definition, lego_grid_object_definition and any inheritors)
lego_nameable_interface<public> := interface():
    GetName() : string
    SetName(NewName:string) : void

# Used in input handlers to provide a template for the input triggers that need to be mapped to an action (lego_grid_inputhandler_gridobject, lego_grid_inputhandler_plot, lego_grid_inputhandler_soloprop)
lego_input_handler_interface<public> := interface():
    Place(Agent : agent, Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void
    Delete(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void
    RotateAntiClockwise(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void
    RotateClockwise(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void
    Previous(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent : agent) : void
    Next(Player : lego_fortplayer_grid, GridDevice : lego_grid_device, Agent:agent) : void
    SwitchTargeting(Player : lego_fortplayer_grid, GridDevice : lego_grid_device) : void