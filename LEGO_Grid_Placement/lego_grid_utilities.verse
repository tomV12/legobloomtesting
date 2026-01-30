using { /UnrealEngine.com/Temporary/SpatialMath }

DoPlotsOverlap<public>(PlotA : lego_grid_plot, PlotB : lego_grid_plot_preview, NewPlotLocation : vector3)<transacts> : logic =
    PlotA_TopLeft : vector2 = vector2:
        X := PlotA.Location.X + PlotA.Rows * PlotA.GetCellXSize() - NearZeroInt
        Y := PlotA.Location.Y + NearZeroInt

    PlotA_BottomRight : vector2 = vector2:
        X := PlotA.Location.X + NearZeroInt
        Y := (PlotA.Location.Y + PlotA.Columns * PlotA.GetCellYSize() - NearZeroInt)

    PlotB_TopLeft : vector2 = vector2:
        X := NewPlotLocation.X + PlotB.Rows * PlotB.CellXSize
        Y := NewPlotLocation.Y

    PlotB_BottomRight : vector2 = vector2:
        X := NewPlotLocation.X
        Y := NewPlotLocation.Y + PlotB.Columns * PlotB.CellYSize

    DoAlignedRectanglesOverlap(PlotA_TopLeft, PlotA_BottomRight, PlotB_TopLeft, PlotB_BottomRight)

DoAlignedRectanglesOverlap<public>(RectangleA_TopLeft : vector2, RectangleA_BottomRight : vector2, RectangleB_TopLeft : vector2, RectangleB_BottomRight : vector2)<transacts> : logic =
    if (RectangleA_TopLeft.X < RectangleB_BottomRight.X or RectangleB_TopLeft.X < RectangleA_BottomRight.X):
        return false
    else if (RectangleA_TopLeft.Y > RectangleB_BottomRight.Y or RectangleB_TopLeft.Y > RectangleA_BottomRight.Y):
        return false
    else return true

GetVector2_FromVector3(InVector : vector3)<computes> : vector2 =
    OutVector := vector2:
        X := InVector.X
        Y := InVector.Y
    OutVector

GetDistanceBetweenVector2(InVectorA : vector3, InVectorB : vector3)<transacts> : float =
    DistanceSq := (InVectorB.X - InVectorA.X) * (InVectorB.X - InVectorA.X) + (InVectorB.Y - InVectorA.Y) * (InVectorB.Y - InVectorA.Y)
    Sqrt(DistanceSq)

GetDistanceBetweenVector3(InVectorA : vector3, InVectorB : vector3)<transacts> : float =
    DistanceSq := (InVectorB.X - InVectorA.X) * (InVectorB.X - InVectorA.X) + (InVectorB.Y - InVectorA.Y) * (InVectorB.Y - InVectorA.Y) + (InVectorB.Z - InVectorA.Z) * (InVectorB.Z - InVectorA.Z)
    Sqrt(DistanceSq)

GetCmFromStuds(StudCount : int)<computes> : float =
    StudCount * 16.0

GetCmFromPlates(PlateCount : int)<computes> : float =
    PlateCount * 6.4


# This function will only be accurate if the prop's dimensions are X=100.0, Y=100.0, Z=100.0
GetCornerLocations<public>(InLocation : vector3, InScale : vector3) : tuple(vector3, vector3) =
    TopLeft := vector3:
        X := InLocation.X + InScale.X * 0.5 * 100
        Y := InLocation.Y - InScale.Y * 0.5 * 100
        Z := InLocation.Z

    BottomRight := vector3:
        X := InLocation.X - InScale.X * 0.5 * 100
        Y := InLocation.Y + InScale.Y * 0.5 * 100
        Z := InLocation.Z
        
    return (TopLeft, BottomRight)

LocationIsInVolume(InLocation : vector3, InTopLeftLocation : vector3, InBottomRightLocation : vector3, Scale : vector3)<transacts> : logic =
        if (InLocation.X > InTopLeftLocation.X or InLocation.X < InBottomRightLocation.X):
            return false
        else if (InLocation.Y < InTopLeftLocation.Y or InLocation.Y > InBottomRightLocation.Y):
            return false
        else if (InLocation.Z < InTopLeftLocation.Z or InLocation.Z > InTopLeftLocation.Z + Scale.Z * 100):
            return false
        else return true

