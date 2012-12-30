{AutoTest} = require('views/autoTest')

class exports.Recorder

    constructor: (@editor, 
                  @editorBody$, 
                  @serializerDisplay, 
                  @recordList,
                  @continuousCheckOff,
                  @recordStop,
                  @expectedResult) ->
        # list of actions being populated by the current recoding session
        # or of the actions of the last record.
        @_recordingSession = []
        # list of all the records retrived from the server (localhost:3000)
        @records           = []
        @checker = new AutoTest()

    ### Functionalities ###

    saveCurrentRecordedTest: (title)->
        @recordStop()
        if !(title.length > 0)
            alert "Please enter a title for this test"
            return
        if !(@._recordingSession.length >0)
            alert "No test recorded for saving"
            return
        record =
            title        : title
            description  : "description du test"
            sequence     : @._recordingSession
            initialState : @.initialState
            finalState   : @.finalState
        $.ajax
            type: "POST"
            url: "/records/"
            data: JSON.stringify(record)
            dataType:'json'
            contentType : "application/json"
            success:(resp)=>
                record.id       = resp.id
                record.title    = resp.title
                record.fileName = resp.fileName
                @._appendRecordElement(record)

    load: ->
        $.get '/records/', (data) =>
            data = JSON.parse(data)
            for record in data
                @._appendRecordElement record

    startRecordSession: () ->
        @._recordingSession = []
        @.serializerDisplay.val null
        @initialState = @getState()
        @.editorBody$.mouseup(@.selectionRecorder)
        @.editorBody$.keyup(@.keyboardRecorder)

    stopRecordSession: () ->
        @.editorBody$.off 'mouseup', @.selectionRecorder
        @.editorBody$.off 'keyup'  , @.keyboardRecorder
        @finalState = @getState()

    getState: () ->
        state =
            html: @.editorBody$.find('#editor-lines').html()
            md  : @.editor.getEditorContent()
        # state =
        #     html: "html2"
        #     md  : "md"
        return state

    restoreState: (state) ->
        if state
            @.editor.setEditorContent(state.md)
            # @editorBody$.html state
            # @editor._readHtml()

    ### Listeners ###
    
    selectionRecorder: =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        serializedEvent =
            selection: serializedSelection

        @_recordingSession.push serializedEvent
        @_refreshRecorder()

    keyboardRecorder: (event) =>
        [metaKeyCode,keyCode] = @editor.getShortCut(event)
        serializedEvent = {}

        if metaKeyCode+keyCode == 'other'
            # don't insert caracters during recording since the recorder is not
            # able to play them.
            # This test doesn't fit all the insertions, but 80% cases, it's 
            # enougth
            throw new Error('No insertion during recording')
        else if metaKeyCode != '' and keyCode == 'other'
            # don't record if only a meta is stroken
            return

        if keyCode in ['up','down','right','left','home','pgUp','pgDwn']
            sel = @editor.getEditorSelection()
            serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
            serializedEvent.selection = serializedSelection

        serializedEvent.keyboard =
            altKey   : event.altKey
            shiftKey : event.shiftKey
            ctrlKey  : event.ctrlKey
            keyCode  : event.which
            which    : event.which

        @_recordingSession.push serializedEvent
        @_refreshRecorder()

    _refreshRecorder: ->
        @serializerDisplay.val JSON.stringify(@_recordingSession)

    playAll: ->
        for record in @records
            @play record
        @_displayResults()

    slowPlayAll: ->
        @slowPlayRecords = @records.slice(0)
        @_slowPlayAllLoop()

    _slowPlayAllLoop: ->
        if @slowPlayRecords.length > 0
            @slowPlayRecord = @slowPlayRecords.shift()
            @slowPlay @slowPlayRecord, true
        else
            @_displayResults()
            console.log 'slowPlayAll finished'

    play: (record) ->
        @restoreState(record.initialState)
        if !record
            record = @_recordingSession
        for action in record.sequence
            @_playAction action
        finalState = @.getState()
        if finalState.md != record.finalState.md
            record.finalStateOK = false
            record.finalStateTxt = "md differs"
        else if finalState.html != record.finalState.html
            record.finalStateOK = false
            record.finalStateTxt = "html differs"
        else
            record.finalStateOK = true

    slowPlay: (record, isAll) =>
        @restoreState(record.initialState)
        if record?
            @_slowPlayingSession = record.sequence.slice(0)
            @slowPlayRecord = record
        else
            @_slowPlayingSession = @_recordingSession.slice(0)
        @editorBody$.focus()
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
            finalState = @.getState()
            if (finalState.md == @slowPlayRecord.finalState.md) and (finalState.html == @slowPlayRecord.finalState.html)
                @slowPlayRecord.finalStateOK = true
            else
                @slowPlayRecord.finalStateOK = false
                debugger
            @_slowPlayAllLoop()
            
    _appendRecordElement: (record) ->
        @recordList.append """
            <div id="record_#{record.id}">
                <span class="btnDiv-RecordLine">
                    <div class="btn-group" >
                        <button class="slowPlay btn btn-primary btn-mini"> > </button>
                        <button class="playQuick btn btn-primary btn-mini"> >> </button>
                        <button class="md btn btn-mini">md</button>
                        <button class="html btn btn-mini">html</button>
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

        element.find('.md').click =>
            @expectedResult(record.finalState.md)

        element.find('.html').click =>
            @expectedResult(record.finalState.html,true)

        element.find('.slowPlay').click =>
            @continuousCheckOff()
            @.serializerDisplay.val JSON.stringify record.sequence
            @.slowPlay(record)

        element.find('.slowPlay').tooltip({title:'Slow play',delay:800})
        element.find('.playQuick').tooltip({title:'Quick play',delay:800})
        element.find('.md').tooltip({title:'Load md final state',delay:800})
        element.find('.html').tooltip({title:'Load html final state',delay:800})
        element.find('.delete').tooltip({title:'Delete',delay:800})
        element.find('.playQuick').click =>
            @continuousCheckOff()
            @.serializerDisplay.val JSON.stringify record.sequence
            @.play(record)
            @_displayResults(record)

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
        if action.selection?
            rangy.deserializeSelection action.selection, @editorBody$[0]
        if action.keyboard?
            downEvent = jQuery.Event "keydown", action.keyboard
            pressEvent = jQuery.Event "keypress", action.keyboard
            upEvent = jQuery.Event "keyup", action.keyboard
            @editorBody$.trigger downEvent
            @editorBody$.trigger pressEvent
            @editorBody$.trigger upEvent
        action.result = @checker.checkLines(@editor)


    ###*
     * display result tests of each record in its corresponding line.
    ###
    _displayResults: (record)->
        
        if record?
            @records = [record]

        for record in @records
            if !(record.finalStateOK == undefined) # check that the record has been played
                actionsInError = []
                for action , i in record.sequence
                    if action.result
                        recordResult = true
                    else
                        recordResult = false
                        actionsInError.push(i)
                    2 # for a clear compiled js 
                el = record.element.find('.resultAction')
                if recordResult and record.finalStateOK
                    el.text('ok')
                    @expectedResult(record.finalState.md)
                    el.addClass('resultActionOK')
                    el.removeClass('resultActionNOK')
                else 
                    if recordResult and !record.finalStateOK
                        errorText = 'Actions went ok but unexpected final state - '
                        errorText += record.finalStateTxt
                        @expectedResult(record.finalState.md)
                    else if !recordResult and record.finalStateOK
                        errorText = 'Actions #{actionsInError} went wrong, but final state is what was expected - '
                    else
                        errorText = 'Actions #{actionsInError} went wrong, and unexpected final state - '
                        errorText += record.finalStateTxt
                        @expectedResult(record.finalState.md)
                        
                    el = record.element.find('.resultAction')
                    el.text(errorText)
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


