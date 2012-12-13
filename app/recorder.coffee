class exports.Recorder

    constructor: (@editor, @editorBody, @serializerDisplay) ->
        @recordingSession = []


    ### Functionalities ###

    saveInitialState: ->
        @initialState = $(@editorBody).html()

    restoreInitialState: ->
        $(@editorBody).html @initialState
        @editor._readHtml()

    recordEvent: (serializedEvent) ->
        @saveInitialState()
        previousRecord = @serializerDisplay.val()
        @serializerDisplay.val previousRecord + "\n" + serializedEvent

    refreshRecorder: ->
        @serializerDisplay.val JSON.stringify(@recordingSession)

    play: ->
        @restoreInitialState()
        for action in @recordingSession
            @playAction action

    slowPlay: =>
        $(@editorBody).focus()
        @restoreInitialState()
        if @recordingSession.length > 0
            action = @recordingSession.shift()
            @playAction action

            setTimeout @slowPlay, 200
        else
            console.log "finished"
            

    playAction: (action) ->
        if action.mouse?
            rangy.deserializeSelection action.mouse, @editorBody
        else
            downEvent = jQuery.Event "keydown", action.keyboard
            pressEvent = jQuery.Event "keypress", action.keyboard
            upEvent = jQuery.Event "keyup", action.keyboard
            sel = @editor.getEditorSelection()
            $(@editorBody).trigger downEvent
            $(@editorBody).trigger pressEvent
            $(@editorBody).trigger upEvent


    ### Listeners ###
    
    mouseRecorder: =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody
        serializedEvent =
            mouse: serializedSelection

        console.log this
        
        @recordingSession.push serializedEvent
        @refreshRecorder()

    keyboardRecorder: (event) =>
        serializedEvent =
            keyboard:
                altKey: event.altKey
                shiftKey: event.shiftKey
                ctrlKey: event.ctrlKey
                keyCode: event.which

        @recordingSession.push serializedEvent
        @refreshRecorder()
