using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Assets }
using { /Verse.org/Colors }


# ==================================================================================================
# Allows the player to select a grid object from a list of available objects to place in the world
# ==================================================================================================

lego_grid_ui := class:
    var ObjectDefinitions : []lego_grid_object_definition = array{}
    AmountOfItemsPerPage : int = 6

    var MainCanvas<private> : canvas = canvas{}
    GetMainCanvas<public>()<transacts> : canvas = MainCanvas

    var CurrentPageIndex<private> : int = 0
    var PagesInCurrentCategory<private> : int = 1

    Widget_Button_Next<private> : button_loud = button_loud{}
    Widget_Button_Previous<private> : button_loud = button_loud{}
    Widget_Button_Close<private> : button_regular = button_regular{}

    Widget_TextBlock_PageIndex<private> : text_block = text_block{}  

    Widget_Button_Items<private> : []button_regular = array{
        button_regular{}, 
        button_regular{}, 
        button_regular{},
        button_regular{},
        button_regular{},
        button_regular{}
    }

    Widget_Texture_Items<private> : []texture_block = array{
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}},
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}},
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}},
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}},
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}},
        texture_block{DefaultImage := LEGO_Grid_Placement.Icons.T_FallbackTexture, DefaultDesiredSize := vector2{X := 200.0, Y := 200.0}}
    }

    Widget_Text_Items<private> : []text_block = array{
        text_block{DefaultTextColor := NamedColors.White},
        text_block{DefaultTextColor := NamedColors.White},
        text_block{DefaultTextColor := NamedColors.White},
        text_block{DefaultTextColor := NamedColors.White},
        text_block{DefaultTextColor := NamedColors.White},
        text_block{DefaultTextColor := NamedColors.White}
    }

    MessageFromString<private><localizes>(SourceString : string) : message = "{SourceString}"

    AnchorPreset_RightBottom : anchors = anchors{
        Minimum := vector2{X := 0.0, Y := 0.0}
        Maximum := vector2{X := 1.0, Y := 1.0}
    }

    var ButtonCallbacks : []cancelable = array{}

    # ------------------------------------------------------------------------------------------------------------------
    # Setup UI
    # ------------------------------------------------------------------------------------------------------------------
    Update<public>(InObjectDefinitions : []lego_grid_object_definition) : void =
        set MainCanvas = CreateMainCanvas()
        set ObjectDefinitions = InObjectDefinitions
        
        SetupButtonInputHandlers()
        SetAndShowCategory()

    SetupButtonInputHandlers() : void =
        for (Callback : ButtonCallbacks):
            Callback.Cancel()

        for (ItemButtonIndex := 0..AmountOfItemsPerPage):
            if (ButtonItemWidget := Widget_Button_Items[ItemButtonIndex]):
                Callback := ButtonItemWidget.OnClick().SubscribeWidgetMessage(OnClick_ItemSelect, ItemButtonIndex)
                set ButtonCallbacks += array{Callback}

        set ButtonCallbacks += array{Widget_Button_Next.OnClick().Subscribe(OnClick_NextPage)}
        set ButtonCallbacks += array{Widget_Button_Previous.OnClick().Subscribe(OnClick_PreviousPage)}
        set ButtonCallbacks += array{Widget_Button_Close.OnClick().Subscribe(OnClick_CloseUI)}

    SetAndShowCategory() : void =
        if (PagesAmount : int = Ceil(ObjectDefinitions.Length / AmountOfItemsPerPage)):
            set PagesInCurrentCategory = PagesAmount
        
        UpdateItemButtons()
        UpdateNavigationButtons()
    
        
    # ------------------------------------------------------------------------------------------------------------------
    # Update UI
    # ------------------------------------------------------------------------------------------------------------------
    UpdateItemButtons() : void =
        for (ButtonIndex := 0..AmountOfItemsPerPage):
            ObjectDefinitionsIndex := GetObjectDefinitionsIndexFromButtonIndex(ButtonIndex)

            if:
                TextureWidget := Widget_Texture_Items[ButtonIndex]
                ButtonWidget := Widget_Button_Items[ButtonIndex]
                TextWidget := Widget_Text_Items[ButtonIndex]
            then:
                ButtonWidget.SetText(MessageFromString("Select"))

                if:
                    ValidObjectDefinition := ObjectDefinitions[ObjectDefinitionsIndex]
                then:
                    TextureWidget.SetImage(ValidObjectDefinition.Texture)
                    TextureWidget.SetVisibility(widget_visibility.Visible)

                    ButtonWidget.SetVisibility(widget_visibility.Visible)
                    ButtonWidget.SetEnabled(true)
                    TextWidget.SetText(MessageFromString("{ValidObjectDefinition.Name}"))
                else:
                    TextureWidget.SetVisibility(widget_visibility.Hidden)                    
                    ButtonWidget.SetVisibility(widget_visibility.Hidden)
                    ButtonWidget.SetEnabled(false)
                    TextWidget.SetText(MessageFromString(""))

        UpdatePageIndexText()

    UpdateNavigationButtons() : void =
        Widget_Button_Next.SetText(MessageFromString("  >  "))
        Widget_Button_Previous.SetText(MessageFromString("  <  "))
        Widget_Button_Close.SetText(MessageFromString("      Close      "))

    UpdatePageIndexText() : void =
        CurrentIndex : int = CurrentPageIndex + 1;
        MaxIndex : int = Clamp(PagesInCurrentCategory, 1, 9999)
        Text := MessageFromString("    {CurrentIndex} / {MaxIndex}    ")
        Widget_TextBlock_PageIndex.SetText(Text)
        Widget_TextBlock_PageIndex.SetTextColor(NamedColors.White)

    GetObjectDefinitionsIndexFromButtonIndex(ButtonIndex : int) : int =
        return ButtonIndex + (AmountOfItemsPerPage * CurrentPageIndex)

    # ------------------------------------------------------------------------------------------------------------------
    # Input Handlers
    # ------------------------------------------------------------------------------------------------------------------
    OnClick_CloseUI<private>(WidgetMSG : widget_message) : void = OnClickedButtonEvent.Signal(-1)
    OnClickedButtonEvent<public> : event(int) = event(int){}

    OnClick_PreviousPage<private>(WidgetMSG : widget_message) : void =
        if (CurrentPageIndex <= 0):
            return

        set CurrentPageIndex -= 1
        UpdateItemButtons()

    OnClick_NextPage<private>(WidgetMSG : widget_message) : void =
        if (CurrentPageIndex + 1 >= PagesInCurrentCategory):
            return
            
        set CurrentPageIndex += 1
        UpdateItemButtons()

    OnClick_ItemSelect<private>(WidgetMSG : widget_message, ButtonIndex : int) : void =
        ObjectDefintionsIndex := GetObjectDefinitionsIndexFromButtonIndex(ButtonIndex)
        OnClickedButtonEvent.Signal(ObjectDefintionsIndex)
        OnClick_CloseUI(WidgetMSG)

    # ------------------------------------------------------------------------------------------------------------------
    # Create UI
    # ------------------------------------------------------------------------------------------------------------------
    CreateMainCanvas<public>() : canvas = canvas:
        Slots := array:
            canvas_slot:
                Anchors := AnchorPreset_RightBottom
                Offsets := margin:
                    Left := 300.0
                    Top := 60.0
                    Right := 300.0
                    Bottom := 60.0
                SizeToContent := false
                Alignment := vector2:
                    X := 0.5
                    Y := 0.5
                ZOrder := 1
                Widget := canvas:
                    Slots := array:
                        CanvasSlot_CreateBackground()
                        canvas_slot:
                            Anchors := AnchorPreset_RightBottom
                            Offsets := margin:
                                Left := 0.0
                                Top := 50.0
                                Right := 0.0
                                Bottom := 0.0
                            SizeToContent := false
                            Alignment := vector2:
                                X := 0.5
                                Y := 0.5
                            ZOrder := 2
                            Widget := stack_box:
                                Orientation := orientation.Vertical
                                Slots := array:
                                    StackSlot_CreateItemSection()


    CanvasSlot_CreateBackground() : canvas_slot = canvas_slot:
        Anchors := AnchorPreset_RightBottom
        Offsets := margin:
            Left := 0.0
            Top := 0.0
            Right := 0.0
            Bottom := 0.0
        SizeToContent := false
        Alignment := vector2:
            X := 0.5
            Y := 0.5
        ZOrder := 0
        Widget := texture_block:
            DefaultImage := UI.T_UI_GridEntitySelection_Background, 
            DefaultDesiredSize := vector2:
                X := 1024.0
                Y := 1024.0


    StackSlot_CreateItemSection() : stack_box_slot = stack_box_slot:
        Widget := stack_box:
            Orientation := orientation.Vertical
            Slots := array:                        
                StackSlot_CreateItemRow(0, 1, 2)
                StackSlot_CreateItemRow(3, 4, 5)
                StackSlot_CreateItemRow(6, 7, 8)
                StackSlot_CreateNavigationRow()


    StackSlot_CreateEmpty(Width : float, Height : float) : stack_box_slot = stack_box_slot:
        HorizontalAlignment := horizontal_alignment.Center
        VerticalAlignment := vertical_alignment.Center
        Widget := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2:
                            X := 0.0
                            Y := 0.5
                        Maximum := vector2:
                            X := 0.0
                            Y := 0.5
                    Offsets := margin:
                        Left := 0.0
                        Top := 0.0
                        Right := Width
                        Bottom := Height                    
                    SizeToContent := false
                    Alignment := vector2:
                        X := 0.0
                        Y := 0.5
                    Widget := canvas{}


    StackSlot_CreateItemRow(IndexA : int, IndexB : int, IndexC : int) : stack_box_slot = stack_box_slot:
        HorizontalAlignment := horizontal_alignment.Center
        VerticalAlignment := vertical_alignment.Center
        Widget := stack_box:
            Orientation := orientation.Horizontal
            Slots := array:
                StackSlot_CreateItem(IndexA)
                StackSlot_CreateItem(IndexB)
                StackSlot_CreateItem(IndexC)


    StackSlot_CreateItem(Index : int) : stack_box_slot =
        if:
            TextureWidget := Widget_Texture_Items[Index]
            Button := Widget_Button_Items[Index]
            Text := Widget_Text_Items[Index]
        then:
            return StackSlot_CreateItem(TextureWidget, Button, Text)
        else:
            return StackSlot_CreateEmpty(0.0, 0.0)


    StackSlot_CreateItem(TextureWidget : widget, ButtonWidget : widget, TextWidget : widget) : stack_box_slot = stack_box_slot:
        HorizontalAlignment := horizontal_alignment.Center
        VerticalAlignment := vertical_alignment.Center
        Padding := margin:
            Left := 0.0
            Top := 25.0
            Right := 0.0
            Bottom := 0.0
        Widget := stack_box:
            Orientation := orientation.Vertical
            Slots := array:
                stack_box_slot:
                    Widget := color_block:
                        DefaultColor := NamedColors.Black
                        DefaultOpacity := 0.0
                        DefaultDesiredSize := vector2:
                            X := 350.0
                            Y := 1.0

                stack_box_slot:
                    Widget := TextureWidget

                stack_box_slot:
                    Padding := margin:
                        Left := 0.0
                        Top := 5.0
                        Right := 0.0
                        Bottom := 0.0
                    Widget := TextWidget

                stack_box_slot:
                    Widget := canvas:
                        Slots := array:
                            canvas_slot:
                                Anchors := AnchorPreset_RightBottom
                                Offsets := margin:
                                    Left := 0.0
                                    Top := 15.0
                                    Right := 0.0
                                    Bottom := 15.0
                                SizeToContent := true
                                Alignment := vector2:
                                    X := 0.5
                                    Y := 0.5
                                ZOrder := 5
                                Widget := ButtonWidget
    

    StackSlot_CreateNavigationRow() : stack_box_slot = stack_box_slot:
        Padding := margin:
            Left := 0.0
            Top := 45.0
            Right := 0.0
            Bottom := 0.0
        HorizontalAlignment := horizontal_alignment.Center
        VerticalAlignment := vertical_alignment.Center
        Widget := stack_box:                                       
            Orientation := orientation.Horizontal
            Slots := array:
                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Padding := margin:
                        Left := 40.0
                        Top := 0.0
                        Right := 40.0
                        Bottom := 0.0
                    Widget := Widget_Button_Previous

                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Widget := Widget_TextBlock_PageIndex

                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Padding := margin:
                        Left := 40.0
                        Top := 0.0
                        Right := 40.0
                        Bottom := 0.0
                    Widget := Widget_Button_Next

                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Padding := margin:
                        Left := 50.0
                        Top := 0.0
                        Right := 40.0
                        Bottom := 0.0
                    Widget := Widget_Button_Close


# ------------------------------------------------------------------------------------------------------------------
# WidgetMessage Wrapper - Allows for the ability to tie additional return data to the OnClick function's callback of the button widgets
# ------------------------------------------------------------------------------------------------------------------
(Listenable : listenable(widget_message)).SubscribeWidgetMessage(OutputFunc : tuple(widget_message, t) -> void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_widget_message(t) {ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)
    
wrapper_widget_message(t : type) := class:
    ExtraData : t;
    OutputFunc : tuple(widget_message, t) -> void
    InputFunc(WidgetMessage : widget_message) : void = OutputFunc(WidgetMessage, ExtraData)
