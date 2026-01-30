using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }


# ============================================================================================================================================
# Represents a zone in the world where players can place grid objects and solo props
# ============================================================================================================================================

Tooltip_PlacementZone_Volume<public><localizes> : message = "The volume that defines the Placement Zone."
Tooltip_PlacementZone_Trigger_NotInZone<public><localizes> : message = "The trigger that fires when a player places an object outside the zone."
Tooltip_PlacementZone_Trigger_Inc_Quest<public><localizes> : message = "The trigger that fires when a player places an object inside the zone."
Tooltip_PlacementZone_AcceptedAssetNames<public><localizes> : message = "The names of the assets that can be placed in the zone."
Tooltip_PlacementZoneChecker_GridDevice<public><localizes> : message = "The grid device that checks for grid object placement."
Tooltip_PlacementZoneChecker_PlacementZones<public><localizes> : message = "The placement zones that the grid device checks for grid object placement."

placement_zone := class(lego_initializable_interface):
    @editable:
        ToolTip := Tooltip_PlacementZone_Volume
    Volume : ?creative_prop = false

    @editable:
        ToolTip := Tooltip_PlacementZone_Trigger_NotInZone
    Trigger_NotInZone : ?trigger_device = false

    @editable:
        ToolTip := Tooltip_PlacementZone_Trigger_Inc_Quest
    Trigger_Inc_Quest : ?trigger_device = false

    @editable:
        ToolTip := Tooltip_PlacementZone_AcceptedAssetNames
    AcceptedAssetNames : []string = array{}

    var Location : vector3 = vector3{}
    var Scale : vector3 = vector3{}
    var TopLeftLocation : vector3 = vector3{}
    var BottomRightLocation : vector3 = vector3{}

    Initialize<override>() : void = 
        if (ValidVolume := Volume?):
            set Location = ValidVolume.GetTransform().Translation
            set Scale = ValidVolume.GetTransform().Scale
            Corners := GetCornerLocations(Location, Scale)
            set TopLeftLocation = Corners(0)
            set BottomRightLocation = Corners(1)

    LocationIsInZone(InLocation : vector3)<transacts> : logic =
        LocationIsInVolume(InLocation, TopLeftLocation, BottomRightLocation, Scale)

    IsAcceptedAssetName(Name : string)<transacts> : logic =
        for (AcceptedAssetName : AcceptedAssetNames):
            if (Name = AcceptedAssetName):
                return true
        return false


# ============================================================================================================================================
# Checks if a grid object is placed in a placement zone and triggers the appropriate triggers
# ============================================================================================================================================

lego_grid_placement_checker := class(creative_device):
    @editable:
        ToolTip := Tooltip_PlacementZoneChecker_GridDevice
    GridDevice : ?lego_grid_device = false

    @editable:
        ToolTip := Tooltip_PlacementZoneChecker_PlacementZones
    PlacementZones : []placement_zone = array{}

    OnBegin<override>()<suspends> : void =
        for (PlacementZone : PlacementZones):
            PlacementZone.Initialize()

        loop:
            if (ValidGridDevice := GridDevice?):
                GridObjectPlacementResponse := ValidGridDevice.OnGridObjectPlaced.Await()
                Agent := GridObjectPlacementResponse(0)
                Name := GridObjectPlacementResponse(1)
                Location := GridObjectPlacementResponse(2)

                for (PlacementZone : PlacementZones):
                    if:
                        PlacementZone.LocationIsInZone(Location) = true
                        PlacementZone.IsAcceptedAssetName(Name) = true
                        ValidTracker := PlacementZone.Trigger_Inc_Quest?
                    then:
                        ValidTracker.Trigger(Agent)
                    else if (ValidTrigger := PlacementZone.Trigger_NotInZone?):
                        ValidTrigger.Trigger(Agent)


                