using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }


RequestSFX<public>(InDevice : creative_device, InID : EN_SFX_ID, InLocation : vector3) : void =
    TaggedObjects := InDevice.FindCreativeObjectsWithTag(sfx_provider_tag{})    
    for (TaggedObject : TaggedObjects, ValidTypedObject := lego_sfx_provider[TaggedObject]):
        ValidTypedObject.RequestSFXByID(InID, InLocation)


sfx_pool<public> := class<concrete>:
    @editable
    ID : EN_SFX_ID = EN_SFX_ID.None
    @editable
    Pool_SFX : []sfx_pool_entry = array{} # Note: Consider having at least 1 audio device per player

    RequestSFXFromPool<public>(InLocation : vector3) : void =
        for (Index -> SFX : Pool_SFX; not SFX.IsInUse?):
            spawn{SFX.RequestSFXFromPoolEntry(Index, ID, InLocation)}
            return

        Logger: log = log{Channel := sfx_provider_log, DefaultLevel := log_level.Normal}
        Logger.Print("RequestSFXFromPool failed: No available SFX devices in {ID.ToString()}", ?Level := log_level.Warning)
        

sfx_pool_entry<public> := class<concrete>:
    @editable
    AudioPlayer : audio_player_device = audio_player_device{}
    var IsInUse<public> : logic = false

    RequestSFXFromPoolEntry<public>(PoolIndex : int, InID : EN_SFX_ID, InLocation : vector3)<suspends> : void =
        if (IsInUse?):
            return

        set IsInUse = true
        if (AudioPlayer.TeleportTo[InLocation, IdentityRotation()])
        {}

        Sleep(0.0)
        AudioPlayer.Play()
        Sleep(2.0) # This value is hardcoded, because it's currently not possible to retrieve the length of an audio clip

        set IsInUse = false


# !!! ================================================================================================================================================ !!!
# IMPORTANT: DO NOT MODIFY THE ORDER OF THESE ENUMS. IF YOU NEED TO ADD A NEW ENUM, ADD IT TO THE END OF THE LIST.
# !!! ================================================================================================================================================ !!!
EN_SFX_ID<public> := enum:
    None,
    Sound1,
    Sound2

(InType : EN_SFX_ID).ToString<public>() : string =
    case (InType):
        EN_SFX_ID.None => return "None"
        EN_SFX_ID.Sound1 => return "Sound1"
        EN_SFX_ID.Sound2 => return "Sound2"

sfx_provider_log<public> := class(log_channel):
sfx_provider_tag<public> := class(lego_utilities_tag){} # --- MUST ASSIGN Tag: Tag_LEGO_fortplayer_manager to the device instance in the level! ---

# ================================================================================================================================================
# Distributes audio_player_devices from an object pool to whoever is requesting them
# ================================================================================================================================================
lego_sfx_provider<public> := class(creative_device):
    @editable
    Pool_SFXCollections : []sfx_pool = array{}
    Logger<protected> : log = log{Channel := sfx_provider_log, DefaultLevel := log_level.Normal}

    RequestSFXByID<public>(InID : EN_SFX_ID, InLocation : vector3) : void=
        for (SFXCollection : Pool_SFXCollections, SFXCollection.ID = InID):
            SFXCollection.RequestSFXFromPool(InLocation)