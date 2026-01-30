using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }


# ========================================================================================================================================
# Represents a No Build Zone in the world
# ========================================================================================================================================

Tooltip_NoBuildZone_Volume<public><localizes> : message = "The volume that defines the No Build Zone."
Tooltip_NoBuildZone_AreaMarker<public><localizes> : message = "The area marker that represents the No Build Zone."

lego_grid_nobuild_zone<public> := class<concrete><unique>(lego_initializable_interface):
    @editable:
        ToolTip := Tooltip_NoBuildZone_Volume
    Volume : creative_prop = creative_prop{}

    var TopLeftLocation : vector3 = vector3{}
    var BottomRightLocation : vector3 = vector3{}

    Initialize<override>() : void =
        Location := Volume.GetTransform().Translation
        Scale := Volume.GetTransform().Scale
        Corners := GetCornerLocations(Location, Scale)
        set TopLeftLocation = Corners(0)
        set BottomRightLocation = Corners(1)