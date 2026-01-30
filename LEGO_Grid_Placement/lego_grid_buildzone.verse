using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }


# ========================================================================================================================================
# Represents an area where a player can build in the world, is only used when a lego_assignable_player_area is assigned
# ========================================================================================================================================

Tooltip_BuildZone_Volume<public><localizes> : message = "The volume that defines the Build Zone."

lego_grid_build_zone<public> := class<concrete><unique>(lego_initializable_interface):
    @editable:
        ToolTip := Tooltip_NoBuildZone_Volume
    Volume : creative_prop = creative_prop{}

    var TopLeftLocation<public> : vector3 = vector3{}
    var BottomRightLocation<public> : vector3 = vector3{}

    Initialize<override>() : void =
        Location := Volume.GetTransform().Translation
        Scale := Volume.GetTransform().Scale
        Corners := GetCornerLocations(Location, Scale)
        set TopLeftLocation = Corners(0)
        set BottomRightLocation = Corners(1)