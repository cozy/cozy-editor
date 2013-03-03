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
            url: "/records/"
            data: JSON.stringify(record)
            dataType:'json'
            contentType : "application/json"
            success:(resp)=>
                record.id       = resp.id
                record.title    = resp.title
                record.fileName = resp.fileName
                @._appendRecordElement(record)

    load : ->
        $.get '/records/', (data) =>
            data = JSON.parse(data)
            for record in data
                @._appendRecordElement record

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
        originalProcessPaste = @editor._processPaste
        _recordingSession = @._recordingSession
        @editor._processPaste = () ->
            # clipboardHtml = @clipboard.html
            action = 
                paste : @clipboard.innerHTML
            originalProcessPaste.call(this)
            action.html = this.linesDiv.innerHTML
            _recordingSession.push action

    stopRecordSession : () ->
        @editor.linesDiv.removeEventListener('mouseup', @selectionRecorder, false)
        @editor.linesDiv.removeEventListener('keydown', @keyboardRecorder, false)
        @editor.linesDiv.removeEventListener('keyup', @keyboardMoveRecorder, false)
        @finalState = @getState()

    getState : () ->
        state =
            html: @.editorBody$.find('#editor-lines').html()
            md  : @.editor.getEditorContent()
        # state =
        #     html: "html2"
        #     md  : "md"
        return state

    restoreState : (state) ->
        if state
            @.editor.replaceContent(state.html)
            # @.editor.setEditorContent(state.md)


    ### Listeners ###
    
    selectionRecorder : =>
        sel = @editor.getEditorSelection()
        serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
        action =
            selection : serializedSelection


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
            serializedSelection = rangy.serializeSelection sel, true, @editorBody$[0]
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
        @restoreState(record.initialState)
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

    _appendRecordElement : (record) ->
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
                    url: "/records/"
                    data:
                        fileName: record.fileName
        @recordList.append element



    _playAction : (action) ->
        
        if action.result? and !action.result
            ### 
            A break point is here because this action has already been played
            and leads to an error...
            Good debug ! :-) 
            ###
            debugger;

        if action.selection?
            rangy.deserializeSelection(action.selection, @editorBody$[0])

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





    _playRandomActionTEST : ()->
        res = {}
        for i in [1..10000]
            action = @_generateRandomAction('keyEvent')
            if res[action.type]
                res[action.type] += 1
            else
                res[action.type] = 1
        console.log res


    _playRandomAction : ()->
        res = {}
        for i in [1..10]
            action = @_generateRandomAction('selection')
            # action = @_generateRandomAction('keyEvent')
            # action = @_generateRandomAction('paste')
            @_playAction(action)
            

    rangeTypes : [
            type      : 'endLastLine'
            weight    : 1
        ,
            type      : 'startFirstLine'
            weight    : 0
        ,
            type      : 'collapsed'
            weight    : 1
        ,
            type      : 'rangeMonoLine'
            weight    : 1
        ,
            type      : 'rangeMultiLine'
            weight    : 1
        ]

    breakpointTypes : [
            type      : 'start'
            weight    : 0
        ,
            type      : 'middle'
            weight    : 0
        ,
            type      : 'end'
            weight    : 1
        ,

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

    _generateRandomAction : (actionType)->
        switch actionType
            
            when 'keyEvent'
                action = @_randomChoice(@keyEventTypes)
            
            when 'selection'
                action = @_randomSelection()
            
            when 'paste'
                action = @_randomChoice(@pasteTypes)

        return action

    _randomSelection : () ->
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
                l       = @_selectRandomLine()
                startBP = @_selectRandomBP(l)
                endBP   = @_selectRandomBP(l)

            when "rangeMultiLine"
                l1      = @_selectRandomLine()
                startBP = @_selectRandomBP(l1)
                l2      = @_selectRandomLine()
                while l2 == l1
                    l2  = @_selectRandomLine()
                endBP = @_selectRandomBP(l2)

        rg = document.createRange()
        rg.setStart(startBP.cont,startBP.offset)
        if endBP
            rg.setEnd(endBP.cont,endBP.offset)
        else
            rg.collapse(true)
        sel = rangy.serializeRange(rg, true, @editorBody$[0])
        return selection : sel 
                

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
        i = Math.min(   n-1,   Math.floor( Math.random()*(n-1) )   )
        return lines[i]

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

    _getRandomEndLine : (line)->
        n = @_getpossibleEndBpNumbers(line)
        i = Math.min(   n-1,   Math.floor( Math.random()*n )   )
        bp = @_getEndBpNumber(line, i)
        return bp

    _getpossibleEndBpNumbers : (line)->
        n = 3
        child = line.lastChild.previousSibling
        while child.childNodes.length != 0
            n += 1
            child = child.lastChild
        return n

    _getEndBpNumber : (line, n) ->
        if n == 0
            return cont : line, offset: line.childNodes.length

        else if n == 1
            return cont : line, offset : line.childNodes.length - 1

        else if n == 2
            cont = line.lastChild.previousSibling
            if cont.length
                offset = cont.length
            else
                offset = cont.childNodes.length
            return cont : cont , offset : offset
        else
            i = 3
            cont = line.lastChild.previousSibling.lastChild
            while i != n
                n += 1
                cont = cont.lastChild
            if cont.length
                offset = cont.length
            else
                offset = cont.childNodes.length
            return cont : cont , offset : offset

    _getpossibleBpNumbers : (line) ->
        possibleBpNumbers = 1 + 3 * line.childNodes.length + 1

