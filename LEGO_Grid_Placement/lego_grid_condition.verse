using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Colors }
using { /Fortnite.com/Devices }

using { LEGOUtilities }

# ============================================================================================================================================
# Conditions that can be checked in a batch using the TypeConditions map when placing objects to make sure the placement is valid, or used in custom functions for other purposes
# ============================================================================================================================================

lego_grid_condition<public> := class:
    IsConditionMet(Row : int, Column : int, Layer : int, InPlot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        true
    
    IsObjectPresent(Row : int, Column : int, Layer : int, InPlot : lego_grid_plot)<decides><transacts> : void =
        InPlot.GridObjects[Row][Column][Layer]?

# Base conditions that must always be met, we want to make sure that the object below can support the object to be placed 
# and that the object to be placed isn't too big for the target plot which would cause overlap
lego_grid_condition_default<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        Plot.GridObjects[Row][Column][Layer - 1]?.CanBuildUpon = true or Layer = 0
        ObjectDefinition.GridCellSize <= Plot.GridCellSize

lego_grid_condition_gridcellsize<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        ObjectDefinition.GridCellSize <= Plot.GridCellSize

# Make sure that an object is on the lowest layer, useful for soil
lego_grid_condition_grounded<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        (Layer = 0)

# Make sure that at least one face of the cell to be placed in is connected to the ground or another asset
# WARNING!!! EXPENSIVE!!! This many array lookups is costly, use sparingly if possible
lego_grid_condition_connected<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, InPlot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        Layer = 0 or 
        IsObjectPresent[Row, Column, Layer - 1, InPlot] and InPlot.Category = en_lego_grid_plot_category.Mosaic or
        IsObjectPresent[Row, Column, Layer - 1, InPlot] and InPlot.GridObjects[Row][Column][Layer - 1]?.Height = InPlot.GridCellSize or 
        IsObjectPresent[Row, Column, Layer + 1, InPlot] or 
        IsObjectPresent[Row - 1, Column, Layer, InPlot] or 
        IsObjectPresent[Row + 1, Column, Layer, InPlot] or 
        IsObjectPresent[Row, Column - 1, Layer, InPlot] or
        IsObjectPresent[Row, Column + 1, Layer, InPlot]

# Make sure that an object is placed upon another object of Type soil, use this for plants!
lego_grid_condition_onsoil<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        Plot.GridObjects[Row][Column][Layer - 1]?.Type = Types.Soil

lego_grid_condition_farmingplot<public> := class(lego_grid_condition):
    IsConditionMet<override>(Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
        Plot.Category = en_lego_grid_plot_category.Farming

# Call this to check that an object meets all conditions in the TypeConditions entry for its Type
AreConditionsMet<public>(Conditions : []lego_grid_condition, Row : int, Column : int, Layer : int, Plot : lego_grid_plot, ObjectDefinition : lego_grid_object_definition)<decides><transacts> : void =
    for (Condition : Conditions):
        Condition.IsConditionMet[Row, Column, Layer, Plot, ObjectDefinition]
