{AutoTest} = require('views/autoTest')

class exports.Recorder

    constructor: (@editor, @editorBody$, @serializerDisplay, @recordList) ->
        # list of actions being populated by the current recoding session
        # or of the actions of the last record.
        @_recordingSession = []
        # list of all the records retrived from the server (localhost:3000)
        @records           = []
        @checker = new AutoTest()

    ### Functionalities ###

    load: ->
        $.get '/records/', (data) =>
            data = JSON.parse(data)
            for record in data
                @._appendRecordElement record

    startRecordSession: () ->
        @._recordingSession = []
        @.serializerDisplay.val null
        @.editorBody$.mouseup(@.mouseRecorder)
        @.editorBody$.keyup(@.keyboardRecorder)

    stopRecordSession: () ->
        @.editorBody$.off 'mouseup', @.mouseRecorder
        @.editorBody$.off 'keyup', @.keyboardRecorder

    ### Listeners ###
    
    mouseRecorder: =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        serializedEvent =
            mouse: serializedSelection

        @_recordingSession.push serializedEvent
        @_refreshRecorder()

    keyboardRecorder: (event) =>
        serializedEvent =
            keyboard:
                altKey: event.altKey
                shiftKey: event.shiftKey
                ctrlKey: event.ctrlKey
                keyCode: event.which

        @_recordingSession.push serializedEvent
        @_refreshRecorder()

    saveCurrentRecordedTest: (title)->
        if !(title.length > 0)
            alert "Please enter a title for this test"
            return
        if !(@._recordingSession.length >0)
            alert "No test recorded for saving"
            return
        record =
            title       : title
            description : "description du test"
            sequence    : @._recordingSession
        $.ajax
            type: "POST"
            url: "/records/"
            data: record
            success:(resp)=>
                console.log resp
                record.id       = resp.id
                record.title    = resp.title
                record.fileName = resp.fileName
                @._appendRecordElement(record)

    saveInitialState: ->
        @initialState = @editorBody$.html()

    restoreInitialState: ->
        @editorBody$.html @initialState
        @editor._readHtml()

    recordEvent: (serializedEvent) ->
        @saveInitialState()
        previousRecord = @serializerDisplay.val()
        @serializerDisplay.val previousRecord + "\n" + serializedEvent

    _refreshRecorder: ->
        @serializerDisplay.val JSON.stringify(@_recordingSession)

    playAll: ->
        for record in @records
            @play record
        @updateElements()

    slowPlayAll: ->
        @slowPlayRecords = @records.slice(0)
        @_slowPlayAllLoop()

    _slowPlayAllLoop: ->
        if @slowPlayRecords.length > 0
            record = @slowPlayRecords.shift()
            @slowPlay record, true
        else
            @updateElements()
            console.log 'slowPlayAll finished'

    play: (record) ->
        @restoreInitialState()
        if !record
            record = @_recordingSession
        for action in record.sequence
            @_playAction action

    slowPlay: (record, isAll) =>
        if record?
            @_slowPlayingSession = record.sequence.slice(0)
        else
            @_slowPlayingSession = @_recordingSession.slice(0)
        @editorBody$.focus()
        @restoreInitialState()
        if !isAll
            @slowPlayRecords=[]
        @_slowPlayLoop()

    _slowPlayLoop: =>
        if @_slowPlayingSession.length > 0
            action = @_slowPlayingSession.shift()
            @_playAction action
            setTimeout @_slowPlayLoop, 300
        else
            console.log "finished a record"
            @_slowPlayAllLoop()
            
    _appendRecordElement: (record) ->
        @recordList.append """
            <div id="record_#{record.id}">
                <span class="btnDiv-RecordLine">
                    <div class="btn-group" >
                        <button class="play btn btn-primary btn-mini">></button>
                        <button class="delete btn btn-mini">X</button>
                    </div>
                </span>
                <span class="resultAction"></span>
                <span class="txtDiv-RecordLine">#{record.fileName}</span>
            </div>
            """
        element = @recordList.children().last()
        record.element = element
        @.add(record)

        element.find('.play').click =>
            @.serializerDisplay.val JSON.stringify record.sequence
            @.slowPlay(record)

        element.find('.delete').click =>
            strconfirm = confirm("Do you want to delete ?")
            if strconfirm
                element.remove()
                @._remove(record)
                $.ajax
                    type: "PUT"
                    url: "/records/"
                    data:
                        fileName: record.fileName

    _playAction: (action) ->
        if action.mouse?
            rangy.deserializeSelection action.mouse, @editorBody$[0]
        else
            downEvent = jQuery.Event "keydown", action.keyboard
            pressEvent = jQuery.Event "keypress", action.keyboard
            upEvent = jQuery.Event "keyup", action.keyboard
            sel = @editor.getEditorSelection()
            @editorBody$.trigger downEvent
            @editorBody$.trigger pressEvent
            @editorBody$.trigger upEvent
        # test that editor structure is valid after the action
        action.result = @checker.checkLines(@editor)

    updateElements: ()->
        for record in @records
            for action in record.sequence
                if action.result == undefined
                    recordResult = 0
                else if action.result
                    recordResult = "ok"
                else
                    recordResult = "nok"
                if recordResult == 0
                    break
                2 # for a clear compiled js 
            if recordResult == 'ok'
                el = record.element.find('.resultAction')
                el.text('ok')
                el.addClass('resultActionOK')
                el.removeClass('resultActionNOK')
            else if recordResult == 'nok'
                el = record.element.find('.resultAction')
                el.text('NOK')
                el.removeClass('resultActionOK')
                el.addClass('resultActionNOK')
            1 # for a clear compiled js 


    add: (record) ->
        @records.push record

    _remove: (record) ->
        i     = @records.indexOf(record)
        front = @records.slice(0,i)
        end   = @records.slice(i+1)
        @records = front.concat end


