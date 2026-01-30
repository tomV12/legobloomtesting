using { /Verse.org/Concurrency }
using { /Verse.org/Simulation }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices/CreativeAnimation }	
using { /Fortnite.com/Playspaces }

lego_utilities_log<public> := class(log_channel):
lego_utilities_tag<public> := class(tag){}

Tooltip_FNBindingsInterface<public><localizes> : message = "trigger_devices to trigger when device specific events occur - allows to use this Verse device with Fortnite devices"

# ============================================================================================================================================
# Math Helpers & Operators
# ============================================================================================================================================
# Check if a float is within a range
(InFloat : float).IsInRange<public>(InLowerBoundIncl : float, InUpperBoundIncl : float)<decides><transacts>: void =
    var Result : logic = false
    if (InFloat >= InLowerBoundIncl and InFloat <= InUpperBoundIncl):
        set Result = true        
    Result?

# Divide an int by another int
DivideInt<public>(Dividend : int, Divisor : int)<decides><transacts>: int =
    var OutResult : ?int = false
    if:
        Divisor > 0
        set OutResult = option{Round[((Dividend * 1.0) / (Divisor * 1.0)) + 0.001]}
    else:
        Logger: log = log{Channel := lego_utilities_log, DefaultLevel := log_level.Normal}
        Logger.Print("Division by 0 is not allowed.")
    OutResult?

# SOURCE: https://dev.epicgames.com/community/snippets/1mD/fortnite-float-to-int-cast-and-operators
Float(InInt : int)<reads><allocates>: float =
    InInt * 0.1

operator'+'(I : int, F : float): float =
    I * 1.0 + F

operator'+'(I : float, F : int): float =
    I * 1.0 + F

operator'-'(I : int, F : float): float =
    I * 1.0 - F

operator'-'(I : float, F : int): float =
    F - I * 1.0

(InIndex : int).IncrementWrapped<public>(InMaxValue : int)<computes>: int =
    if (InIndex < InMaxValue):
        return InIndex + 1
    else:
        return 0

(InIndex : int).DecrementWrapped<public>(InMaxValue : int)<computes>: int =
    if (InIndex > 0):
        return InIndex - 1
    else:
        return InMaxValue

StringToMessage<public><localizes>(InString : string)<transacts>: message = "{InString}"

# Helper function to get the delta from a start time in Seconds
GetElapsedTime<public>(InStartTime : float) : float =
    GetSimulationElapsedTime() - InStartTime

# --------------------------------------------------------------------------------------------------------------------------------------------
# Array helpers
# --------------------------------------------------------------------------------------------------------------------------------------------
(Array : []t where t : subtype(comparable)).ContainsAll<public>(InArray : []t)<decides><transacts>: void =
    var FoundMatches : int = 0
    for (MaybeMatch : Array, InArray.Find[MaybeMatch]):
        set FoundMatches += 1
    FoundMatches = Array.Length

(Array : []t where t : subtype(comparable)).ContainsAny<public>(InArray : []t)<decides><transacts>: void =
    var FoundMatches : int = 0
    for (MaybeMatch : Array, InArray.Find[MaybeMatch]):
        set FoundMatches += 1
    FoundMatches <> 0

(Array : []t where t : subtype(comparable)).ContainsNone<public>(InArray : []t)<decides><transacts>: void =
    var FoundMatches : int = 0
    for (MaybeMatch : Array, InArray.Find[MaybeMatch]):
        set FoundMatches += 1
    FoundMatches = 0

# It seems Array.RemoveFirstElement[] and Array.RemoveAllElements() does fail sometimes - here is a brute force solution
ManualRemoveElement<public>(InArray : []t, InElement : t where t : subtype(comparable))<transacts>: []t =
    var OutArray : []t = array{}
    for (Element : InArray, Element <> InElement):
        set OutArray += array{Element}
    OutArray

# Reimplementation of the Unreal Engine function
AddElementUnique<public>(InArray : []t, InElement : t where t : subtype(comparable))<transacts>: []t =
    if (InArray.Find[InElement]):
        return InArray
    else:
        return InArray + array{InElement}
