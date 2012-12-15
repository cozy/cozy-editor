class exports.Recorder

    constructor: (@editor, @editorBody, @serializerDisplay, @_slowPlayingSession) ->
        @recordingSession = []
        @records = []


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

    playAll: ->
        for record in @records
            @play record

    slowPlayAll: ->
        @slowPlayRecords = @records.slice(0)
        @_slowPlayAllLoop()

    _slowPlayAllLoop: ->
        if @slowPlayRecords.length > 0
            record = @slowPlayRecords.shift()
            @slowPlay record, true
        else
            console.log 'slowPlayAll finished'

    play: (record) ->
        @restoreInitialState()
        for action in @recordingSession
            @playAction action

    slowPlay: (record, isAll) =>
        if record?
            @_slowPlayingSession = record.sequence.slice(0)
        else
            @_slowPlayingSession = @recordingSession.slice(0)
        $(@editorBody).focus()
        @restoreInitialState()
        @slowPlayRecords
        if !isAll
            @slowPlayRecords=[]
        @_slowPlayLoop()

    _slowPlayLoop: =>
        if @_slowPlayingSession.length > 0
            action = @_slowPlayingSession.shift()
            @playAction action
            setTimeout @_slowPlayLoop, 300
        else
            @_slowPlayAllLoop()
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

    add: (record) ->
        @records.push record

    remove: (record) ->
        i     = @records.indexOf(record)
        front = @records.slice(0,i)
        end   = @records.slice(i+1)
        @records = front.concat end

    ### Listeners ###
    
    mouseRecorder: =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody
        serializedEvent =
            mouse: serializedSelection

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
