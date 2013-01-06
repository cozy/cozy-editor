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
        @keyEvent = document.createEvent('KeyboardEvent')

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
        # re number lines id so that final state will have same ids after played
        @editor._readHtml() 
        @initialState = @getState()
        # listen events on bubbling phase so that the editor reacts before ( the
        # editor listen the capturing phase which takes place before)
        @editor.linesDiv.addEventListener('mouseup', @selectionRecorder, false)
        @editor.linesDiv.addEventListener('keydown', @keyboardRecorder, false)
        @editor.linesDiv.addEventListener('keyup', @keyboardMoveRecorder, false)

    stopRecordSession: () ->
        @editor.linesDiv.removeEventListener('mouseup', @selectionRecorder, false)
        @editor.linesDiv.removeEventListener('keydown', @keyboardRecorder, false)
        @editor.linesDiv.removeEventListener('keyup', @keyboardMoveRecorder, false)
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
            @.editor.replaceContent(state.html)
            # @.editor.setEditorContent(state.md)

    ### Listeners ###
    
    selectionRecorder: =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        serializedEvent =
            selection: serializedSelection

        @_recordingSession.push serializedEvent
        @_refreshResultDisplay()

    keyboardRecorder: (event) =>
        [metaKeyCode,keyCode] = @editor.getShortCut(event)
        serializedEvent = {}

        if metaKeyCode+keyCode == 'other'
            # don't insert caracters during recording since the recorder is not
            # able to play them.
            # This test doesn't fit all the insertions, but 80% cases, it's 
            # enougth
            alert 'No insertion during recording'
            throw new Error('No insertion during recording')
        else if metaKeyCode != '' and keyCode == 'other'
            # don't record if only a meta is stroken
            return

        if keyCode in ['up','down','right','left','home','pgUp','pgDwn']
        #     sel = @editor.getEditorSelection()
        #     serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        #     console.log 'keyboardRecorder detect a keyboard move : ' + keyCode + ' ' + serializedSelection
        #     serializedEvent.selection = serializedSelection
        else
            serializedEvent.keyboard =
                altKey   : event.altKey
                shiftKey : event.shiftKey
                ctrlKey  : event.ctrlKey
                keyCode  : event.which
                which    : event.which

            @_recordingSession.push serializedEvent
            @_refreshResultDisplay()

    keyboardMoveRecorder: (event) =>
        [metaKeyCode,keyCode] = @editor.getShortCut(event)
        serializedEvent = {}

        if keyCode in ['up','down','right','left','home','pgUp','pgDwn']
            sel = @editor.getEditorSelection()
            serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
            serializedEvent.selection = serializedSelection
            @_recordingSession.push serializedEvent
            @_refreshResultDisplay()

    _refreshResultDisplay: ->
        @serializerDisplay.val JSON.stringify(@_recordingSession)

    playAll: ->
        for record in @records
            @play record

    play: (record) ->
        if !record
            record = @_recordingSession
        if record == []
            return
        if record.currentStep
            record.currentStep = null
        @restoreState(record.initialState)
        for action in record.sequence
            @_playAction action
        record.displayResult( @getState() )
        finalState = @.getState()
        if finalState.html != record.finalState.html
            record.finalStateOK = false
            errorText = 'Actions ok, but final html differs'
            record.setResult(errorText,'finalHTMLNOK')
        else if finalState.md != record.finalState.md
            record.finalStateOK = false
            errorText = 'Actions ok, but final md differs'
            record.setResult(errorText,'finalMdNOK')
        else
            record.finalStateOK = true
            record.setResult('ok','resultActionOK')


    displayResult : (finalState) ->
            if finalState.html != @finalState.html
                @finalStateOK = false
                errorText = 'Actions ok, but final html differs'
                @setResult(errorText,'finalHTMLNOK')
            else if finalState.md != @finalState.md
                @finalStateOK = false
                errorText = 'Actions ok, but final md differs'
                @setResult(errorText,'finalMdNOK')
            else
                @finalStateOK = true
                @setResult('ok','resultActionOK')

    setResult : (msg,classError) ->
            el = @element.find('.resultAction')
            actionsInError = []
            for action , i in @sequence
                if action.result
                    recordResult = true
                else
                    recordResult = false
                    actionsInError.push(i)
                2 # for a clear compiled js 

                el.text(msg)
                el.removeClass('resultActionOK'  )
                el.removeClass('resultActionNOK' )
                el.removeClass('finalHTMLNOK'    )
                el.removeClass('finalMdNOK'      )
                el.addClass(classError)

    playStep : () ->
        if !@currentStep?
            @currentStep = 0
            @recorder.restoreState(@initialState)
        @recorder._playAction @sequence[@currentStep]
        if @currentStep == @sequence.length - 1
            @currentStep = null
            @displayResult(@recorder.getState())
        else
            el = @element.find('.resultAction')
            if @sequence[@currentStep].result
                el.removeClass('resultActionNOK')
                el.addClass('resultActionOK')
                el.text('step ' + (@currentStep+1) + '/' + @sequence.length + ' OK')
            else
                el.removeClass('resultActionOK')
                el.addClass('resultActionNOK')
                el.text('step ' + (@currentStep+1) + '/' + @sequence.length + ' NOK')
            @currentStep +=1

    _appendRecordElement: (record) ->
        element = $  """
            <div id="record_#{record.id}">
                <span class="btnDiv-RecordLine">
                    <div class="btn-group" >
                        <button class="playQuick btn btn-primary btn-mini"> >> </button>
                        <button class="playStep btn btn-primary btn-mini"> >| </button>
                        <button class="btn btn-mini dropdown-toggle" data-toggle="dropdown">
                            <span class="caret"></span>
                        </button>
                        <ul class="dropdown-menu">
                            <li><a class="html-ini" href="#">Initial html -> editor2</a></li>
                            <li><a class="md-ini" href="#">Initial md -> editor2</a></li>
                            <li><a class="html" href="#">Expected final html -> editor2</a></li>
                            <li><a class="md" href="#">Expected final md -> editor2</a></li>
                            <li><a class="delete" href="#">Delete test</a></li>
                        </ul>
                    </div>
                </span>
                <span class="resultAction"></span>
                <span class="txtDiv-RecordLine">#{record.fileName}</span>
            </div>
            """
        @recordList.append element
        record.element       = element
        
        record.setResult     = @setResult
        record.playStep      = @playStep
        record.currentStep   = null
        record.displayResult = @displayResult
        record.recorder      = @

        @.add(record)

        element.find('.playStep').click =>
            record.playStep()

        element.find('.md-ini').click =>
            @expectedResult(record.initialState.md,false)

        element.find('.html-ini').click =>
            @expectedResult(record.initialState.html,true)

        element.find('.md').click =>
            @expectedResult(record.finalState.md)

        element.find('.html').click =>
            @expectedResult(record.finalState.html,true)

        element.find('.playQuick').tooltip({title:'Quick play',delay:800})
        element.find('.playStep').tooltip({title:'Play step by step',delay:800})

        element.find('.playQuick').click =>
            @continuousCheckOff()
            @.serializerDisplay.val JSON.stringify record.sequence
            @.play(record)

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
            k = action.keyboard
            
            @keyEvent.initKeyEvent(
                'keydown'  ,      #  in DOMString typeArg,
                true       ,      #  in boolean canBubbleArg,
                true       ,      #  in boolean cancelableArg,
                null       ,      #  in nsIDOMAbstractView viewArg,  Specifies UIEvent.view. This value may be null.
                k.ctrlKey  ,      #  in boolean ctrlKeyArg,
                k.altKey   ,      #  in boolean altKeyArg,
                k.shiftKey ,      #  in boolean shiftKeyArg,
                k.altKey   ,      #  in boolean metaKeyArg,
                k.keyCode  ,      #  in unsigned long keyCodeArg,
                k.which)          #  in unsigned long charCodeArg);
            @editor.linesDiv.dispatchEvent(@keyEvent)
        action.result = @checker.checkLines(@editor)


    add: (record) ->
        @records.push record

    _remove: (record) ->
        i     = @records.indexOf(record)
        front = @records.slice(0,i)
        end   = @records.slice(i+1)
        @records = front.concat end


