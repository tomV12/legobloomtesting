using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Colors/NamedColors }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Simulation/Tags }

using { LEGOUtilities }

Tooltip_GridClusters_Extent<public><localizes> : message = "The extent of each grid cluster (X = Y)."
Tooltip_GridClusters_SizeX<public><localizes> : message = "The number of grid clusters in the X direction."
Tooltip_GridClusters_SizeY<public><localizes> : message = "The number of grid clusters in the Y direction."
Tooltip_GridClusters_DebugVisualization<public><localizes> : message = "Enable debug visualization for grid clusters."

# ========================================================================================================================================
# Subdivides the map into a grid of clusters, each cluster containing a set of plots
# Helps with optimizing the search for plots in a given area
# ========================================================================================================================================
lego_grid_cluster_manager<public> := class<unique>:
    @editable:
        ToolTip := Tooltip_GridClusters_Extent
    GridClusterExtent : float = 1000.0

    @editable:
        ToolTip := Tooltip_GridClusters_SizeX
    GridClustersSizeX : int = 0

    @editable:
        ToolTip := Tooltip_GridClusters_SizeY
    GridClustersSizeY : int = 0
    
    @editable:
        ToolTip := Tooltip_GridClusters_DebugVisualization
    EnableDebugVisualization : logic = false

    var Owner : creative_device = creative_device{}
    var GridClusters : []lego_grid_cluster = array{}

    GridClusterDebugDraw<public> : debug_draw = debug_draw{}
    GridClusterDebugDraw_Player<public> : debug_draw = debug_draw{}
    Logger : log = log{Channel := lego_grid_device_log, DefaultLevel := log_level.Normal}


    Initialize<public>(InDevice : creative_device) : void =
        set Owner = InDevice
        CornerLocation : vector3 = Owner.GetTransform().Translation

        for (Index_Y := 0..GridClustersSizeY - 1, Index_X := 0..GridClustersSizeX - 1):
            NewCluster := lego_grid_cluster:
                TopLeftLocation := vector3:
                    X := CornerLocation.X + Index_X * GridClusterExtent
                    Y := CornerLocation.Y + Index_Y * GridClusterExtent

                BottomRightLocation := vector3:
                    X := CornerLocation.X + (Index_X + 1) * GridClusterExtent
                    Y := CornerLocation.Y + (Index_Y + 1) * GridClusterExtent

            set GridClusters += array{NewCluster}

        Logger.Print("{GridClusters.Length} Grid clusters created")

        if (EnableDebugVisualization?):
           CreateDebugVisualization()

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Add / Remove Plots
    # --------------------------------------------------------------------------------------------------------------------------------------------
    AddToGridClusters(InPlot : lego_grid_plot)<transacts> : void =
        if (Cluster := GetGridClusterAtLocation[InPlot.Location]):
            Cluster.AddPlot(InPlot)
        else:
            Logger.Print("Failed to sort plot into grid cluster", ?Level := log_level.Warning)

    RemoveFromGridClusters(InPlot : lego_grid_plot)<transacts> : void =
        if:
            Cluster := GetGridClusterAtLocation[InPlot.Location]
            Cluster.RemovePlot[InPlot]
        else:
            Logger.Print("Failed to remove plot from grid cluster", ?Level := log_level.Warning)

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Retrieval Methods
    # --------------------------------------------------------------------------------------------------------------------------------------------
    GetGridClusterAtLocation(InLocation : vector3)<transacts><decides> : lego_grid_cluster =
        var Result : ?lego_grid_cluster = false

        if (GridClusters.Length > 0):
            # Grid Cluster coordinates
            X : float = (InLocation.X - Owner.GetTransform().Translation.X) / GridClusterExtent
            Y : float = (InLocation.Y - Owner.GetTransform().Translation.Y) / GridClusterExtent
            ClusterX := Floor[X]
            ClusterY := Floor[Y]
            
            # Check bounds
            if (ClusterX < 0 or ClusterX >= GridClustersSizeX or ClusterY < 0 or ClusterY >= GridClustersSizeY):
                false
            
            Index := ClusterY * GridClustersSizeX + ClusterX

            # Check if cluster is valid
            if (ValidGridCluster := GridClusters[Index]):
                set Result = option{ValidGridCluster}

        Result?

    # Get all adjacent clusters to a given cluster to ensure plots on the edges are not missed for overlap checks
    GetAdjacentClusters<public>(InCluster : lego_grid_cluster)<transacts> : []lego_grid_cluster =
        var OutClusters : []lego_grid_cluster = array{}
        InClusterCenter := InCluster.GetCenterLocation()
        
        if:
            # Calculate cluster indices for input cluster
            ClusterX := Floor[(InClusterCenter.X - Owner.GetTransform().Translation.X) / GridClusterExtent]
            ClusterY := Floor[(InClusterCenter.Y - Owner.GetTransform().Translation.Y) / GridClusterExtent]
        then:        
            # Check all 8 adjacent cells (including diagonals)
            for (OffsetY := -1..1):
                for (OffsetX := -1..1, not (OffsetX = 0 and OffsetY = 0)):                    
                    # Calculate adjacent cell indices
                    AdjX := ClusterX + OffsetX
                    AdjY := ClusterY + OffsetY
                        
                    # Check bounds
                    if:
                        AdjX >= 0
                        AdjX < GridClustersSizeX
                        AdjY >= 0
                        AdjY < GridClustersSizeY
                    then:
                        # Calculate 1D index from 2D coordinates
                        AdjIndex := AdjY * GridClustersSizeX + AdjX
                        
                        # Add adjacent cluster to output if valid
                        if:
                            AdjIndex >= 0 and AdjIndex < GridClusters.Length
                            ValidCluster := GridClusters[AdjIndex]
                        then:
                            set OutClusters += array{ValidCluster}
        OutClusters

    # --------------------------------------------------------------------------------------------------------------------------------------------
    # Debug Visualization
    # --------------------------------------------------------------------------------------------------------------------------------------------
    CreateDebugVisualization<public>() : void =
        GridClusterDebugDraw.Clear()
        
        Extent := vector3:
            X := GridClusterExtent
            Y := GridClusterExtent
            Z := 20.0

        for (PlotCluster : GridClusters):
            GridClusterDebugDraw.DrawBox(
                PlotCluster.BottomRightLocation, rotation{}, 
                ?Extent := Extent,
                ?Color := Blue,
                ?DrawDurationPolicy := debug_draw_duration_policy.Persistent)

    CreateActiveClusterDebugVisualization(InCluster : []lego_grid_cluster) : void =
        Extent := vector3:
            X := GridClusterExtent * 0.475
            Y := GridClusterExtent * 0.475
            Z := 25.0

        for (GridCluster : InCluster):
            GridClusterDebugDraw_Player.DrawBox(
                GridCluster.GetCenterLocation(), rotation{}, 
                ?Extent := Extent,
                ?Color := Red,
                ?DrawDurationPolicy := debug_draw_duration_policy.SingleFrame,
                ?Thickness := 5.0)


# ========================================================================================================================================
# Represents a cluster of plots in the grid
# ========================================================================================================================================
lego_grid_cluster<public> := class<unique>:
    var Plots<protected> : []lego_grid_plot = array{}
    var TopLeftLocation<public> : vector3 = vector3{}
    var BottomRightLocation<public> : vector3 = vector3{}

    AddPlot<public>(InPlot : lego_grid_plot)<transacts> : void =
        set Plots = AddElementUnique(Plots, InPlot)

    AddPlots<public>(InPlots : []lego_grid_plot) : void =
        for (Plot : InPlots):
            set Plots = AddElementUnique(Plots, Plot)

    RemovePlot<public>(InPlot : lego_grid_plot)<decides><transacts> : void =
        for (Index -> Plot:Plots):
            if:
                Plot = InPlot
                ModifiedPlots := Plots.RemoveElement[Index]
            then:
                set Plots = ModifiedPlots

    RemovePlots<public>(InPlots : []lego_grid_plot) : void =
        var UpdatedPlots : []lego_grid_plot = array{}
        for (Plot : InPlots, not Plots.Find[Plot]):
                set UpdatedPlots = AddElementUnique(UpdatedPlots, Plot)
        set Plots = UpdatedPlots

    GetCenterLocation<public>()<transacts> : vector3 =
        vector3:
            X := Min(TopLeftLocation.X, BottomRightLocation.X) + Abs(BottomRightLocation.X - TopLeftLocation.X) * 0.5, 
            Y := Min(TopLeftLocation.Y, BottomRightLocation.Y) + Abs(BottomRightLocation.Y - TopLeftLocation.Y) * 0.5, 
            Z := 0.0

    GetPlots<public>()<transacts> : []lego_grid_plot =
        Plots
