{AutoTest} = require('views/autoTest')
selection  = require('CNeditor/selection').selection

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

    saveCurrentRecordedTest : (title)->
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
            url: "records/"
            data: JSON.stringify(record)
            dataType:'json'
            contentType : "application/json"
            success:(resp)=>
                record.id       = resp.id
                record.title    = resp.title
                record.fileName = resp.fileName
                @._prependRecordElement(record)


    load : ->
        $.get 'records/', (data) =>
            data = JSON.parse(data)
            data.sort (a,b) ->
                if Number(a.id) < Number(b.id)
                    return -1
                return 1

            for record in data
                @._prependRecordElement record
            return true
        $.get 'pastes/', (data) =>
            data = JSON.parse(data)
            @pasteDataArray = []
            for record in data
                @pasteDataArray.push(record.html)
            return true

    ###*
     * Records the content of the clipboard in an array that is sent for storage
     * to the server. This data can then be used to prepare test cases of paste.
    ###
    startPasteSession : () ->
        @originalProcessPaste = @editor._processPaste
        originalProcessPaste  = @originalProcessPaste
        @._recordingPasteSession = []
        _recordingPasteSession = @._recordingPasteSession
        @editor._processPaste = () ->
            action =
                pasteHtml : @clipboard.innerHTML
            _recordingPasteSession.push @clipboard.innerHTML
            originalProcessPaste.call(this)

    stopPasteSession : () ->
        @editor._processPaste = @originalProcessPaste
        $.ajax
            type: "POST"
            url: "pastes/"
            data: JSON.stringify(@._recordingPasteSession)
            dataType:'json'
            contentType : "application/json"

    ###*
     * Records selection change, paste and keyboard events.
     * When record is stoped, data are sent to the server for storage.
    ###
    startRecordSession : () ->
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

        # Record paste events
        @originalProcessPaste = @editor._processPaste
        originalProcessPaste  = @originalProcessPaste
        _recordingSession = @._recordingSession
        @editor._processPaste = () ->
            action =
                paste : @clipboard.innerHTML
            originalProcessPaste.call(this)
            action.html = this.linesDiv.innerHTML
            _recordingSession.push action

    stopRecordSession : () ->
        @editor.linesDiv.removeEventListener('mouseup', @selectionRecorder, false)
        @editor.linesDiv.removeEventListener('keydown', @keyboardRecorder, false)
        @editor.linesDiv.removeEventListener('keyup', @keyboardMoveRecorder, false)
        @editor._processPaste = @originalProcessPaste
        @finalState = @getState()

    getState : () ->
        state =
            html: @.editor.linesDiv.innerHTML
            md  : @.editor.getEditorContent()
        return state

    _restoreState : (state) ->
        if state
            @.editor.replaceContent(state.html)
            if state.selection
                @editor.deSerializeSelection(state.selection)
                # rangy.deserializeSelection(state.selection, @editorBody$[0])


    ### Listeners ###

    selectionRecorder : =>
        # sel = @editor.serializeSel()
        # serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        action =
            selection : @editor.serializeSel()


        @_recordingSession.push action
        # @_refreshResultDisplay()

    ###*
     * Record keydown events : listen events on bubbling phase so that the
     * editor has already done its modifications.
     * @param  {[type]} event [description]
     * @return {[type]}       [description]
    ###
    keyboardRecorder : (event) =>
        [metaKeyCode,keyCode] = @editor.getShortCut(event)
        shortCut = metaKeyCode + '-' + keyCode

        console.log shortCut

        # don't insert caracters during recording since the recorder is not
        # able to play them.
        # This test doesn't fit all the insertions, but 80% cases, it's
        # enougth
        if shortCut == '-other'
            alert 'No insertion during recording'
            throw new Error('No insertion during recording')

        # don't record if only a meta is stroken
        else if metaKeyCode != '' and keyCode == 'other'
            return

        # Ctrl-V : do not record the key action. It is directly recorded by
        # startRecording()
        else if shortCut == 'Ctrl-V'
            return

        if keyCode in ['up','down','right','left','home','pgUp','pgDwn']
        #     sel = @editor.getEditorSelection()
        #     serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        #     console.log 'keyboardRecorder detect a keyboard move : ' + keyCode + ' ' + serializedSelection
        #     action.selection = serializedSelection
        else
            action =
                keyboard :
                    altKey   : event.altKey
                    shiftKey : event.shiftKey
                    ctrlKey  : event.ctrlKey
                    keyCode  : event.which
                    which    : event.which
                # html : @.editorBody$.find('#editor-lines').html()
                html : @editor.linesDiv.innerHTML


            @_recordingSession.push action


    keyboardMoveRecorder : (event) =>
        [metaKeyCode,keyCode] = @editor.getShortCut(event)
        serializedEvent = {}

        if keyCode in ['up','down','right','left','home','pgUp','pgDwn']
            sel = @editor.getEditorSelection()
            serializedSelection = @editor.serializeRange(sel.getRangeAt(0))
            serializedEvent.selection = serializedSelection
            @_recordingSession.push serializedEvent
            # @_refreshResultDisplay()

    _refreshResultDisplay : ->
        @serializerDisplay.val JSON.stringify(@_recordingSession)

    playAll : ->
        for record in @records
            @play record

    play : (record) ->
        if !record
            record = @_recordingSession
        if record == []
            return
        if record.currentStep
            record.currentStep = null
        @_restoreState(record.initialState)
        actionsInError = []
        for action, i in record.sequence
            res = @_playAction(action)
            if !res
                actionsInError.push(i)
        finalState = @.getState()
        record.displayResult(finalState)
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
        el.removeClass('resultActionOK'  )
        el.removeClass('resultActionNOK' )
        el.removeClass('finalHTMLNOK'    )
        el.removeClass('finalMdNOK'      )
        if actionsInError.length == 0
            el.text(msg)
            el.addClass(classError)
        else
            el.text('ERROR in actions : ' + actionsInError)
            el.addClass('resultActionNOK')


    ###*
     * Play the current step of the record. This function is called as a method
     * of the record element, this refers to the element, not to the recorder
     * object.
     * @return {[type]} [description]
    ###
    playStep : () ->
        el = @element.find('.resultAction')
        if @currentStep == null
            @currentStep = 0
            @recorder._restoreState(@initialState)
            nextAction = @recorder._getFullActionType(@sequence[0])
            res = @recorder.checker.checkLines(@recorder.editor)
            if !res
                $('#well-editor').css('background-color','#c10000')
            el.addClass('resultActionOK')
            el.text('Initial state restored - next action = ' + nextAction)
            return
        @recorder._playAction @sequence[@currentStep]
        if @currentStep == @sequence.length - 1
            @currentStep = null
            @displayResult(@recorder.getState())
        else
            if @sequence[@currentStep].result
                el.removeClass('resultActionNOK')
                el.addClass('resultActionOK')
                el.text('step ' + (@currentStep+1) + '/' + @sequence.length + ' OK')
            else
                el.removeClass('resultActionOK')
                el.addClass('resultActionNOK')
                el.text('step ' + (@currentStep+1) + '/' + @sequence.length + ' NOK')
            @currentStep +=1

    _prependRecordElement : (record) ->
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
                    url: "records/"
                    data:
                        fileName: record.fileName

        @recordList.prepend element



    _playAction : (action) ->

        if action.result? and !action.result
            ###
            A break point is here because this action has already been played
            and leads to an error...
            Good debug ! :-)
            ###
            sel = @.editor.getEditorSelection()
            rg  = sel.getRangeAt(0)
            startContainer = rg.startContainer
            startOffset    = rg.startOffset
            endContainer   = rg.endContainer
            endOffset      = rg.endOffset
            debugger;

        if action.selection?
            # rangy.deserializeSelection(action.selection, @editorBody$[0])
            @editor.deSerializeSelection(action.selection)
            @editor.newPosition = true

        if action.paste?
            @editor.clipboard.innerHTML = action.paste
            @editor.updateCurrentSelIsStartIsEnd()
            @editor._processPaste()

        if action.keyboard?

            k = action.keyboard
            if @keyEvent.initKeyEvent # ff
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
            else # chrome
                @__triggerKeyboardEvent(@editor.linesDiv,k)
        # check the result
        res = true
        if action.html
            res = this.editor.linesDiv.innerHTML == action.html

        return action.result = res && @checker.checkLines(@editor)

    ###*
     * An alternative keyboard event triger for Chrome wich is buggy on this
     * point...
     * @param  {[type]} el       [description]
     * @param  {[type]} keyboard [description]
     * @return {[type]}          [description]
    ###
    __triggerKeyboardEvent : (el, keyboard) ->
        eventObj = if document.createEventObject? then document.createEventObject() else document.createEvent("Events")

        if eventObj.initEvent
          eventObj.initEvent("keydown", true, true)

        eventObj.keyCode  = keyboard.keyCode
        eventObj.which    = keyboard.keyCode
        eventObj.ctrlKey  = keyboard.ctrlKey
        eventObj.altKey   = keyboard.altKey
        eventObj.shiftKey = keyboard.shiftKey

        if el.dispatchEvent?
            el.dispatchEvent(eventObj)
        else
            el.fireEvent("onkeydown", eventObj)

    add : (record) ->
        @records.push record

    _remove : (record) ->
        i     = @records.indexOf(record)
        front = @records.slice(0,i)
        end   = @records.slice(i+1)
        @records = front.concat end


    ###*
     * Returns a string describing the action.
     * @param  {[type]} action [description]
     * @return {[type]}        [description]
    ###
    _getFullActionType : (action) ->
        if action.keyboard
            type = action.keyboard.which
            switch type
                when 13
                    type = 'return'
                when 8
                    type = 'backspace'
                when 46
                    type = 'suppr'
                when 9
                    if action.keyboard.shiftKey
                        type = 'un-tab'
                    else
                        type = 'tab'
                when 66
                    if action.keyboard.ctrlKey
                        type = 'bold'
                when 65
                    if action.keyboard.altKey
                        type = 'toggle'

        else if action.selection
            type = 'selection'
        else if action.paste
            type = 'paste'
        return type



    ###*
     * The mad monkey ! Main method to start a random serie of tests.
    ###
    launchMadMonkey : (nbRound)=>
        if !nbRound
            nbRound = 0

        @isMonkeyOn = true
        historySummary = {}
        history = []
        res = true
        sel = @editor.getEditorSelection()
        @_initEditorForMadMonkey()

        that = this
        # if error while simulation, catch it to save history.
        @editor.document.defaultView.onerror = (errormsg, url, lineNumber) =>
            # save the history to replay the bug
            if @isMonkeyOn
                @_saveMadMonkeyJourney(history)
                @isMonkeyOn = false
            # Display failure information
            fullType = @_getFullActionType(action)
            serializerDisplay = $ "#resultText"
            checkLog  = serializerDisplay.val()
            checkLog += '\n !!! RANDOM TEST FOUND A FAILURE : cf console \n'
            checkLog += 'action fullType : ' + fullType + ' - action data :\n'
            checkLog += JSON.stringify(action) + '\nInitial html :\n'
            checkLog += '\nInitial selection : ' + selBeforeAction + ' \n'
            serializerDisplay.val(checkLog)

            # tools to help debug
            window.chc = that
            window.restoreStep = (n) ->
                step = history[n]
                content = step.htmlBeforeAction
                that.editor.replaceContent content
                that.editor.deSerializeSelection(step.selBeforeAction)
                # rangy.deserializeSelection(step.selBeforeAction, that.editorBody$[0])

            window.playStep = (n) ->
                that._playAction(history[n].action)

            console.error(errormsg, lineNumber)
            ###
             Good debugg ! ! !  :-)
            ###
            debugger
            window.restoreStep(history.length-1)
            window.playStep(history.length-1)


        # play random actions
        start = new Date().getTime()
        for i in [1..10000] by 1

            # if the number of line is too small, open a new content
            if @editor.linesDiv.children.length < 5
                @_initEditorForMadMonkey()

            # create a random action
            actionType = @_randomChoice(@actionTypes)
            try
                action = @_generateRandomAction(actionType.type)
            catch e
                if e.message == 'no range to choose'
                    @_initEditorForMadMonkey()
                    continue
                else
                    throw e

            # add action and context in history
            selBeforeAction  = @editor.serializeRange(sel.getRangeAt(0))
            htmlBeforeAction = @editor.linesDiv.innerHTML
            fullType         = @_getFullActionType(action)
            action.fullType  = fullType
            history.push
                selBeforeAction  : selBeforeAction
                htmlBeforeAction : htmlBeforeAction
                action           : action
                fullType         : fullType

            # play action
            res = res && @_playAction(action)
            if fullType == 'bold'
                action = @_generateRandomAction('selection')
                res    = @_playAction(action)

            # manage historysummary
            if historySummary[fullType]
                historySummary[fullType] += 1
            else
                historySummary[fullType] = 1

            # check action result
            if !res
                break
        end = new Date().getTime()

        @isMonkeyOn = false
        serializerDisplay = $ "#resultText"
        checkLog = serializerDisplay.val()


        if res
            checkLog += '\n random test successfull\n'
            checkLog += JSON.stringify(historySummary)
            checkLog += '\nduration : ' + (end-start)/1000 +'s (' + (end-start)/10000 +'ms/action)'

            serializerDisplay.val(checkLog)
            $('#well-editor').css('background-color','')
            history = []
            if nbRound > 1
                window.setTimeout(@launchMadMonkey,5000, nbRound-1)

        else
            # Display failure information
            checkLog += ' !!! RANDOM TEST FOUND A FAILURE : cf console \n\n'
            checkLog += 'action fullType : ' + fullType + '\n\naction data :\n'
            checkLog += JSON.stringify(action) + '\n\nInitial html :\n'
            checkLog += '\nInitial selection : ' + selBeforeAction + ' \n'
            checkLog += htmlBeforeAction

            # Save last action
            @_saveMadMonkeyJourney(history)

            # Display result
            serializerDisplay.val(checkLog)
            $('#well-editor').css('background-color','#c10000')

            debugger

        return true

    _initEditorForMadMonkey : () ->
        # content = require('views/templates/content-shortlines-large')
        content = require('views/templates/content-for-mad-monkey')
        @editor.replaceContent content()
        action = @_generateRandomAction('selection')
        res    = @_playAction(action)

    _saveMadMonkeyJourney : (history)->
        @_recordingSession = []
        n = history.length
        nbOfStepsToSave = 3
        nmin = Math.max(n-nbOfStepsToSave,0)
        nmax = n-1
        for i in [nmin .. nmax] by 1
            step = history[i]
        # for step in history
            action = step.action
            delete action.result
            @_recordingSession.push(action)
        @initialState =
            html      : history[nmin].htmlBeforeAction
            selection : history[nmin].selBeforeAction
        @finalState =
            html : @.editor.linesDiv.innerHTML
        @saveCurrentRecordedTest('Random test in failure')


    actionTypes : [
            type   : 'selection'
            weight : 1
        ,
            type   : 'paste'
            weight : 1
        ,
            type   : 'keyEvent'
            weight : 3
        ,
            type   : 'bold'
            weight : 1
        ]

    rangeTypes : [
            type   : 'endLastLine'
            weight : 1
        ,
            type   : 'startFirstLine'
            weight : 1
        ,
            type   : 'collapsed'
            weight : 4
        ,
            type   : 'rangeMonoLine'
            weight : 4
        ,
            type   : 'rangeMultiLine'
            weight : 4
        ]

    breakpointTypes : [
            type   : 'start'
            weight : 1
        ,
            type   : 'middle'
            weight : 3
        ,
            type   : 'end'
            weight : 1
        ]

    keyEventTypes : [
            type     : 'return'
            weight   : 1
            keyboard :
                altKey   : false
                shiftKey : false
                ctrlKey  : false
                keyCode  : 13
                which    : 13
        ,
            type     : 'suppr'
            weight   : 1
            keyboard :
                altKey   : false
                shiftKey : false
                ctrlKey  : false
                keyCode  : 46
                which    : 46
        ,
            type     : 'backspace'
            weight   : 1
            keyboard :
                altKey   : false
                shiftKey : false
                ctrlKey  : false
                keyCode  : 8
                which    : 8
        ,
            type     : 'tab'
            weight   : 1
            keyboard :
                altKey   : false
                shiftKey : false
                ctrlKey  : false
                keyCode  : 9
                which    : 9
        ,
            type     : 'un-tab'
            weight   : 1
            keyboard :
                altKey   : false
                shiftKey : true
                ctrlKey  : false
                keyCode  : 9
                which    : 9
        ,
            type     : 'toggle'
            weight   : 1
            keyboard :
                altKey   : true
                shiftKey : false
                ctrlKey  : false
                keyCode  : 65
                which    : 65
        ]
    linesDistance : [
            weight   : 100
            val      : 1
        ,
            weight   : 65
            val      : 2
        ,
            weight   : 45
            val      : 3
        ,
            weight   : 25
            val      : 4
        ,
            weight   : 15
            val      : 5
        ,
            weight   : 8
            val      : 6
        ,
            weight   : 4
            val      : 7
        ,
            weight   : 2
            val      : 8
        ,
            weight   : 2
            val      : 9
        ,
            weight   : 2
            val      : 10
        ]



    _randomChoice : (types) ->
        if !types.totalWeight
            totalWeight = 0
            for type in types
                totalWeight += type.weight
                type.sliceUp = totalWeight
            types.totalWeight = totalWeight

        w = Math.random() * types.totalWeight
        for type in types
            if w < type.sliceUp
                return type
        return types[types.length - 1]



    _getRandomNum : (a,b) ->
        return Math.min( b ,  a + Math.floor( Math.random()*(b-a+1) )   )



    _generateRandomAction : (actionType)->
        switch actionType

            when 'keyEvent'
                action = keyboard : @_randomChoice(@keyEventTypes).keyboard

            when 'selection'
                action = selection : @_randomSelection()

            when 'paste'
                action = @_randomPaste()

            when 'bold'
                action =
                        keyboard :
                            altKey   : false
                            shiftKey : false
                            ctrlKey  : true
                            keyCode  : 66
                            which    : 66
                        selection : @_randomSelection(true)

        return action



    _randomPaste : () ->
        l = @pasteDataArray.length
        i = @_getRandomNum(0,l-1)
        action = paste : @pasteDataArray[i]



    _randomSelection : (onlyNonEmptyRange) ->

        rangeType = @_randomChoice(@rangeTypes)

        if onlyNonEmptyRange
            while rangeType.type.slice(0,5) != 'range'
                rangeType = @_randomChoice(@rangeTypes)

        switch rangeType.type

            when "endLastLine"
                startBP = @_getRandomEndLine(@editor.linesDiv.lastChild)

            when "startFirstLine"
                startBP = @_getRandomStartLine(@editor.linesDiv.firstChild)

            when 'collapsed'
                l       = @_selectRandomLine()
                startBP = @_selectRandomBP(l)

            when "rangeMonoLine"
                # find any range inside a line
                if !onlyNonEmptyRange
                    l = @_selectRandomLine()
                    startBP = @_selectRandomBP(l)
                    endBP   = @_selectRandomBP(l)
                # find a non empty range
                else
                    # impossible if all lines are empty
                    if @editor.linesDiv.textContent == ''
                        throw new Error('no range to choose')
                    # loop until a non empty line
                    l = @_selectRandomLine()
                    while l.textContent == ''
                        l = @_selectRandomLine()
                    # find 2 random bp
                    startBP = @_selectRandomBP(l)
                    endBP   = @_selectRandomBP(l)
                    # check that the 2 breakpoints have caracters between them
                    rg = @editor.document.createRange()
                    rg.setStart(endBP.cont,endBP.offset)
                    rg.setEnd(startBP.cont,startBP.offset)
                    while rg.toString() == ''
                        startBP = @_selectRandomBP(l)
                        endBP   = @_selectRandomBP(l)
                        # check that the 2 breakpoints have caracters between them
                        rg.setStart(endBP.cont,endBP.offset)
                        rg.setEnd(startBP.cont,startBP.offset)
                    # sbpn = selection.normalizeBP(startBP.cont,startBP.offset)
                    # ebpn = selection.normalizeBP(endBP.cont,endBP.offset)
                    # while sbpn.cont == ebpn.cont && sbpn.offset == ebpn.offset
                    #     endBP = @_selectRandomBP(l)
                    #     ebpn  = selection.normalizeBP(endBP.cont,endBP.offset)

            when "rangeMultiLine"
                ar = @_selectRandomTwoLines()
                l1 = ar[0]
                l2 = ar[1]
                startBP = @_selectRandomBP(l1)
                endBP   = @_selectRandomBP(l2)

                # if !onlyNonEmptyRange
                # # If onlyNonEmptyRange then :
                # #  - check that startBP is not at the end of the line
                # #  - check that endBP is not at the beginning of the line
                # # The reason is that for meta data (bold), only the selected
                # # part of the 1st line will be taken into.
                # else
                #     # impossible if less than thwo lines are not empty
                #     nbNonEmptyLine = 0
                #     for l in @editor.linesDiv.childNodes
                #         if l.textContent != ''
                #             nbNonEmptyLine += 1
                #     if nbNonEmptyLine < 2
                #         throw new Error('no range to choose')

                #     # choose 2 lines with at least one not empty
                #     ar = @_selectRandomTwoLines()
                #     l1 = ar[0]
                #     l2 = ar[1]
                #     while l1.textContent == '' or l2.textContent == ''
                #         ar = @_selectRandomTwoLines()
                #         l1 = ar[0]
                #         l2 = ar[1]

                #     # Choose a breakoint in each, but not at the end of start
                #     # line nor at the beginning of endLine.
                #     startBP = @_selectRandomBP(l1)
                #     endBP   = @_selectRandomBP(l2)
                #     start = selection.getLineDivIsStartIsEnd(
                #                             startBP.cont, startBP.offset)
                #     end   = selection.getLineDivIsStartIsEnd(
                #                             endBP.cont, endBP.offset)
                #     while start.isEnd
                #         startBP = @_selectRandomBP(l1)
                #         start = selection.getLineDivIsStartIsEnd(
                #                             startBP.cont, startBP.offset)
                #     while end.isStart
                #         endBP   = @_selectRandomBP(l2)
                #         end   = selection.getLineDivIsStartIsEnd(
                #                             endBP.cont   , endBP.offset )

        rg = @editor.document.createRange()
        rg.setStart(startBP.cont,startBP.offset)
        if endBP
            rg.setEnd(endBP.cont,endBP.offset)
            # if start and end are not respected, it is because end is before
            # start : just inverse the breakpoint to create the range.
            if rg.startContainer != startBP.cont         \
              or rg.startOffset  != startBP.offset       \
              or rg.endContainer != endBP.cont           \
              or rg.endOffset    != endBP.offset
                rg.setStart(endBP.cont,endBP.offset)
                rg.setEnd(startBP.cont,startBP.offset)

        else
            rg.collapse(true)

        return @editor.serializeRange(rg)



    ###*
     * Returns an array of 2 random lines. The probability of a couple is as
     * small as its distance between the 2 lines is high.
    ###
    _selectRandomTwoLines : () ->
        lines = @editor.linesDiv.childNodes
        linesNumber = lines.length
        if linesNumber == 1
            return [ lines[0], lines[0] ]

        distance = @_randomChoice(@linesDistance)

        while distance.val >= linesNumber
            distance = @_randomChoice(@linesDistance)
        i = @_getRandomNum(0,lines.length - 1 - distance.val)

        return [ lines[i], lines[i+distance.val] ]


    ###*
     * Choose a random line except the first and last ones.
     *
     * @return {element} The div of the choosen line
    ###
    _selectRandomLine : () ->
        lines = @editor.linesDiv.childNodes
        n = lines.length
        # i between 0 and n-1 (we don't choose neither the first line
        # nor the last one)
        i = @_getRandomNum(0,n-1)
        line = lines[i]
        return line


    _selectRandomBP : (line) ->
        # the number of possible breakpoints is at the beginning of line
        # + 3 possible posistions
        bpType = @_randomChoice(@breakpointTypes)
        switch bpType.type
            when 'start'
                bp = @_getRandomStartLine(line)
            when 'middle'
                bp = @_getRandomMiddleLine(line)
            when 'end'
                bp = @_getRandomEndLine(line)
        return bp


    _getRandomMiddleLine : (line) ->
        # count the number of possible offsets
        children = Array.prototype.slice.call(line.childNodes)
        num = children.length + 1
        children.pop() # remove br
        while children.length !=0
            child = children.pop()
            if child.childNodes.length != 0
                num += child.childNodes.length + 1
                newChildren = Array.prototype.slice.call(child.childNodes)
                children = children.concat(newChildren)
            else if child.length
                if child.length == 0
                    num += 1
                else if child.length == 1
                    num += 2
                else
                    num += 3
            else
                num += 1
        # choose a random bp between 0 and num-1 :
        n = @_getRandomNum(0,num-1)
        # find the corresponding bp :
        @nAlreadySeen = -1
        @_getMiddleBP(line, n)


    _getMiddleBP : (cont, ntarget ) ->
        if cont.nodeName == 'BR'
            return
        @nAlreadySeen += 1
        if ntarget == @nAlreadySeen
            return cont:cont, offset:0
        else
            children = cont.childNodes
            n = 0
            # a non empty element
            if children.length != 0
                for child in children
                    bp = @_getMiddleBP(child,ntarget)
                    if bp
                        return bp
                    @nAlreadySeen += 1
                    n += 1
                    if ntarget == @nAlreadySeen
                        return cont:cont, offset:n
            # a text node : 2 possible breakpoints (middle and end)
            else if cont.length
                @nAlreadySeen += 1
                if ntarget == @nAlreadySeen
                    return cont:cont, offset:1
                @nAlreadySeen += 1
                if ntarget == @nAlreadySeen
                    return cont:cont, offset:cont.length
            # an empty element
            else
                @nAlreadySeen += 1
                if ntarget == @nAlreadySeen
                    return cont:cont, offset:0

        # if non returned, then return null
        return null


    _getRandomStartLine : (line)->
        # count the number of bp corresponding to the beginning of the line.
        firstChildNb = 0
        child = line
        while child.firstChild
            firstChildNb += 1
            child = child.firstChild
        n = firstChildNb+1
        # choose a random bp in those (i random between 0 and n-1)
        i = @_getRandomNum(0,n-1)
        cont = line
        n = 0
        while n != i && cont.firstChild
            cont = cont.firstChild
            n += 1
        return cont:cont, offset:0


    _getRandomEndLine : (line)->
        # count the number of bp corresponding to the end of the line.
        n = 3
        child = line.lastChild.previousSibling
        while child.childNodes.length != 0
            n += 1
            child = child.lastChild
        # choose a random bp in those
        i = @_getRandomNum(0,n-1)
        bp = @_getEndBpNumber(line, i)
        return bp


    _getEndBpNumber : (line, n) ->
        # bp after </br>
        if n == 0
            return cont : line, offset: line.childNodes.length
        # bp before </br>
        else if n == 1
            return cont : line, offset : line.childNodes.length - 1
        # pb at the end of the element before </br>
        else if n == 2
            cont = line.lastChild.previousSibling
            if cont.length # a text node
                offset = cont.length
            else # an element
                offset = cont.childNodes.length
            return cont : cont , offset : offset
        # bp in one of the nested lastChild of the element before </br>
        else
            i = 3
            cont = line.lastChild.previousSibling.lastChild
            while i != n && cont.lastChild
                i += 1
                cont = cont.lastChild
            if cont.length
                offset = cont.length
            else
                offset = cont.childNodes.length
            return cont : cont , offset : offset

