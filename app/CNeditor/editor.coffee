### ------------------------------------------------------------------------
# CLASS FOR THE COZY NOTE EDITOR
#
# usage :
#
# newEditor = new CNEditor( iframeTarget,callBack )
#   iframeTarget = iframe where the editor will be nested
#   callBack     = launched when editor ready, the context
#                  is set to the editorCtrl (callBack.call(this))
# properties & methods :
#   replaceContent    : (htmlContent) ->  # TODO: replace with markdown
#   _keyDownCb : (e) =>
#   _insertLineAfter  : (param) ->
#   _insertLineBefore : (param) ->
#
#   editorIframe      : the iframe element where is nested the editor
#   editorBody$       : the jquery pointer on the body of the iframe
#   _lines            : {} an objet, each property refers a line
#   _highestId        :
#   _firstLine        : points the first line : TODO : not taken into account
###

require('./logging')

md2cozy      = require('./md2cozy').md2cozy
selection    = require('./selection').selection
Task         = require('./task')
HotString    = require('./hot-string')
Tags         = require('./tags')
Line         = require('./line')

realtimer    = require('./realtimer')

module.exports = class CNeditor

    ###
    #   Constructor : newEditor = new CNEditor( iframeTarget,callBack )
    #       iframeTarget = iframe where the editor will be nested
    #       callBack     = launched when editor ready, the context
    #                      is set to the editorCtrl (callBack.call(this))
    ###
    constructor : (editorTarget, callBack) ->

        # 1- var
        @editorTarget  = editorTarget
        @editorTarget$ = $(@editorTarget)
        @callBack = callBack

        # 2- Initialisation of the Tasks -
        # Counter for temporary tasks id waiting
        # to receive their id from server.
        @_internalTaskCounter = 0
        # all tasks created or loaded since the load of page
        @_taskList = []
        # a list of tasks waiting to be sent to server.
        @_tasksToBeSaved = {}
        # a list of tasks modified since last addHistory()
        @_tasksModifSinceLastHistory = {}
        # init the socketio connection
        Task.initialize () =>
            @taskCanBeUsed = Task.canBeUsed

        # 3- launch loard editor in synchrone or async whether the editor is in
        # a div or an iframe.
        if @editorTarget.nodeName == "IFRAME"
            @isInIframe = true
            @editorTarget$.on 'load', @loadEditor
            @editorTarget.src = ''
        else if @editorTarget.nodeName == "DIV"
            @isInIframe = false
            @loadEditor()

        # return a ref to the editor's controler
        return this


    loadEditor : () =>
        # preparation of the iframe
        if @isInIframe
            editor_html$ = @editorTarget$.contents().find("html")
            @editorBody$ = editor_html$.find("body")
            editor_head$ = editor_html$.find("head")
            cssLink = '<link id="editorCSS" '
            cssLink += 'href="stylesheets/CNeditor.css" rel="stylesheet">'
            editor_head$.html(cssLink)

        # preparation of the div
        else
            @editorBody$ = @editorTarget$

        @editorBody = @editorBody$[0]

        # a ref to the document (different wether the editor is in an iframe or
        # in a div)
        @document = @editorBody.ownerDocument

        # Create div that will contains line
        linesDiv  = document.createElement('div')
        @linesDiv = linesDiv
        linesDiv.setAttribute('id','editor-lines')
        linesDiv.setAttribute('class','editor-frame')
        linesDiv.contentEditable =  true
        @editorBody$.append(linesDiv)
        if @isInIframe
            linesDiv.style.overflowY = 'auto'
            linesDiv.style.position  = 'absolute'
            linesDiv.style.top       = 0
            linesDiv.style.bottom    = 0
            linesDiv.style.right     = 0
            linesDiv.style.left      = 0


        # init clipboard div and url popover
        @_initClipBoard()
        @_initUrlPopover()

        # initialisation of the hot sting manager
        @_hotString = new HotString(this)

        # init Tags helper
        @Tags = new Tags()

        # set the properties of the editor
        @_lines      = {}            # contains every line
        @newPosition = true          # true if cursor has moved
        @_highestId  = 0             # last inserted line identifier
        @_deepest    = 1             # current maximum indentation
        @_firstLine  = null          # pointer to the first line
        # @hotString   = ''            # the string to detect hotStrings

        # init history
        HISTORY_SIZE  = 100
        @HISTORY_SIZE = HISTORY_SIZE
        @_history     =               # for history management
            index         : HISTORY_SIZE - 1
            history       : new Array(HISTORY_SIZE)
            historySelect : new Array(HISTORY_SIZE)
            historyScroll : new Array(HISTORY_SIZE)
            historyPos    : new Array(HISTORY_SIZE)
            modifiedTask  : new Array(HISTORY_SIZE)

        @_lastKey     = null      # last pressed key (avoid duplication)

        # get a reference on the selection object of the editor
        @currentSel = sel : @getEditorSelection()

        # if chrome => listen to keyup to correct the insertion of the
        # first caracter of an empty line
        @isFirefox = `'MozBoxSizing' in document.documentElement.style`
        @isSafari = Object.prototype.toString.call(window.HTMLElement)
        @isSafari = @isSafari.indexOf('Constructor') > 0
        @isChrome = !@isSafari &&
                 (`'WebkitTransform' in document.documentElement.style`)
        @isChromeOrSafari = @isChrome or @isSafari

        # initialize event listeners
        @linesDiv.addEventListener('drop', (e)->
            e.preventDefault()
        )
        @enable()

        # callback
        @callBack.call(this)



    _mousedownCb : (e) =>
        # console.info '== editor._mousedownCb()'

        # if a hotstring is under preparation, let hotstring controler deal with
        # the new keystroke
        if @_hotString.isPreparing
            @_hotString.mouseDownCb(e)

        # if the mousedown occurs outside of a tag, then set all tags to
        # uneditable so that selection can not end within a tag.
        startCont = this.document.getSelection().getRangeAt(0).startContainer
        startSeg = selection.getSegment(e.target, 0)
        if !startSeg.dataset.type
            @Tags.setTagUnEditable()

    ###*
     * When the user click in the editor, mouseup event will set @newPosition to
     * true and take actions depending on selection location and editor state.
    ###
    _mouseupCb : (e) =>
        # console.info '== editor._mouseupCb()'
        @newPosition = true

        # In case the mousedownCb set tags to uneditable, then revert.
        @Tags.setTagEditable()

        # A- if a hotstring is preparing, give hand to the hotString controler
        if @_hotString.isPreparing
            if @_hotString.isInAuto(e.target)
                @_hotString.mouseUpInAutoCb(e)
                return true

        # B- else deal selection of the editor
        rg = this.document.getSelection().getRangeAt(0)
        startSeg = selection.getSegment(rg.startContainer)
        endSeg   = selection.getSegment(rg.endContainer)

        # 1- if carret is in the button of a task, move it
        if startSeg.dataset.type == 'taskBtn'
            @_setCaret(startSeg.nextSibling,0)
        else if endSeg.dataset.type == 'taskBtn'
            @_setCaret(endSeg.nextSibling,0)

        # 2- if selection has an end which is a tag (hotString, reminder,
        # contact...) but not the other, then put all the selection within the
        # tag.
        if (startSeg.dataset.type && !endSeg.dataset.type)
            @setSelection(rg.startContainer, rg.startOffset,
                          startSeg         , startSeg.childNodes.length)
            endSeg = startSeg
        else if (!startSeg.dataset.type && endSeg.dataset.type)
            @setSelection(endSeg         , 0 ,
                          rg.endContainer, rg.endOffset)
            startSeg = endSeg

        # 3- if hotstring is preparing but the selection is no longer in the
        # hotString segment : reset hotString.
        if @_hotString.isPreparing and startSeg != @_hotString._hsSegment
            @_hotString.reset('current')

        # 4- when in a meta segment (contact, reminder etc...), edit it.
        switch startSeg.dataset.type
            when 'contact', 'reminder', 'htag'
                if !@_hotString.isPreparing
                    rg = this.document.getSelection().getRangeAt(0)
                    @Tags.remove(startSeg)
                    @_hotString.edit(startSeg, rg)
                    while false # otherwise bug in ff debugger...
                        d

        return true




    _clickCB : (e) =>
        console.info "== editor._clickCB()"
        @_lastKey = null
        # if the start of selection after a click is in a link, then show
        # url popover to edit the link.
        @updateCurrentSel()
        segments = @_getLinkSegments()
        if segments
            if e.ctrlKey
                url = segments[0].href
                window.open(url,'_blank')
                e.preventDefault()
            else
                @_showUrlPopover(segments,false)
                e.stopPropagation()
                e.preventDefault()

        # if a hot string is under preparation, re init the process.
        if @hotString.isPreparing
            @hotString.reInit()

        return true



    _pasteCB : (event) =>
        @paste event



    _registerEventListeners : () ->

        # listen keydown on capturing phase (before bubbling)
        # main actions triger.
        @linesDiv.addEventListener('keydown', @_keyDownCbTry, true)
        @linesDiv.addEventListener('keyup', @_keyupCb, false)
        @linesDiv.addEventListener('keypress', @_keypressCb)

        # Listen to mouse to detect when caret is moved
        @linesDiv.addEventListener('mouseup', @_mouseupCb, true)
        @linesDiv.addEventListener('mousedown', @_mousedownCb, true)

        # Click and paste call backs
        @editorBody$.on('click', @_clickCB)
        @editorBody$.on 'paste', @_pasteCB



    _unRegisterEventListeners : () ->
        # listen keydown on capturing phase (before bubbling)
        # main actions triger.
        @linesDiv.removeEventListener('keydown', @_keyDownCbTry, true)
        @linesDiv.removeEventListener('keyup', @_keyupCb, false)
        @linesDiv.removeEventListener('keypress', @_keypressCb)

        # Listen to mouse to detect when caret is moved
        @linesDiv.removeEventListener('mouseup', @_mouseupCb, true)
        @linesDiv.removeEventListener('mousedown', @_mousedownCb, true)

        # Click and paste call backs
        @editorBody$.off('click', @_clickCB)
        @editorBody$.off('paste', @_pasteCB)



    disable : () ->
        @isEnabled = false
        @_unRegisterEventListeners()



    enable : () ->
        @isEnabled = true
        @_registerEventListeners()


    ###* -----------------------------------------------------------------------
     * Set focus on the editor
    ###
    setFocus : () ->
        @linesDiv.focus()


    ###* -----------------------------------------------------------------------
     * Methods to deal selection on an iframe
     * This method is modified during construction if the editor target is not
     * an iframe
     * @return {selection} The selection on the editor.
    ###
    getEditorSelection : () ->
        return this.document.getSelection()
        # return rangy.getIframeSelection @editorTarget


    ###* -----------------------------------------------------------------------
     * this method is modified during construction if the editor target is not
     * an iframe
     * @return {String} Returns the serialized current selection within the
     *                  editor. In case serialisation is impossible (for
     *                  instance if there is no selectio within editor), then
     *                  false is returned.
    ###
    saveEditorSelection : () ->
        sel = this.document.getSelection()
        if sel.rangeCount == 0
            return false
        return  @serializeRange(sel.getRangeAt(0))



    _initTaskContent : (taskDiv) ->
        segment = taskDiv.firstChild.nextSibling
        while segment.nodeName != 'BR'
            segment = segment.nextSibling
            taskDiv.removeChild(segment.previousSibling)
        span = this.document.createElement('SPAN')
        span.className = 'CNE_task'
        txt = this.document.createTextNode('A new task')
        span.appendChild(txt)
        taskDiv.insertBefore(span,segment)
        @_setSelectionOnNode(txt)
        @_addHistory()


    ###*
     * Turns a lineDiv in a task, creates the model of the task and link it to
     * the lineDiv
     * @param  {Element} lineDiv The lineDiv
    ###
    _turnIntoTask : (lineDiv) ->
        if !lineDiv
            lineDiv = @updateCurrentSel().startLineDiv
        return @_turneLineIntoTask(lineDiv)



    _turneLineIntoTask : (lineDiv) ->
        if !@taskCanBeUsed
            return false

        # add button
        btn = this.document.createElement('SPAN')
        btn.className = 'CNE_task_btn'
        btn.dataset.type = 'taskBtn'
        @Tags._tagList.push(btn)
        if @isChromeOrSafari
            text = this.document.createTextNode(' ')
        else
            text = this.document.createTextNode('\u00a0')
        btn.appendChild(text) # insert for arrow keys navigation
        btn.addEventListener 'click', @_toggleTaskCB
        lineDiv.insertBefore(btn, lineDiv.firstChild)

        # add lineDiv attibut
        lineDiv.dataset.type  = 'task'
        lineDiv.dataset.state = 'undone'

        # creation of the model of the task
        @_createTaskForLine(lineDiv)

        return lineDiv



    _turneTaskIntoLine : (taskDiv) ->

        # remove button
        btn = taskDiv.firstChild
        btn.removeEventListener('click', @_toggleTaskCB)
        @Tags.remove(btn)
        taskDiv.removeChild(btn)

        # taskDiv attibutes
        taskDiv.task          = null
        taskDiv.dataset.type  = ''
        taskDiv.dataset.state = ''
        taskDiv.dataset.id    = ''



    _toggleTaskCB : (e) =>
        # lineDiv = @_getSelectedLineDiv()
        @_addHistory()
        lineDiv = selection.getLineDiv(e.target)
        btn = lineDiv.firstChild
        if lineDiv.dataset.state == 'done'
            lineDiv.dataset.state = 'undone'
            @_setCaret(btn.nextSibling,0)
            @_stackTaskChange(lineDiv.task,'undone')
        else
            lineDiv.dataset.state = 'done'
            @_setCaret(btn.nextSibling,0)
            @_stackTaskChange(lineDiv.task,'done')

        @editorTarget$.trigger jQuery.Event('onChange')

        return lineDiv



    _detectTaskChange : () ->
        lineDiv = @currentSel.startLineDiv
        if lineDiv
            isTask = @currentSel.isStartInTask
        else
            sel = @updateCurrentSel()
            lineDiv = sel.startLineDiv
            isTask = sel.isStartInTask
        if isTask
            @_stackTaskChange(lineDiv.task, 'modified')
        return true


    ###* -----------------------------------------------------------------------
     * When a line is a task (its div has dataset.type = task) and we don't have
     * the corresponding model of task, we then create this Task.
     * It for instance happens when we create a task within the editor.
     * @param  {Element} lineDiv The line div we will attach the task to..
     * @param {Boolean} isRedo True if the task is re-created by a reDo.
    ###
    _createTaskForLine : (lineDiv, isRedo) ->
        t = new Task(description:lineDiv.textContent.slice(1))
        lineDiv.task = t
        t.lineDiv = lineDiv
        @_taskList.push(t)
        if isRedo
            t.internalId = lineDiv.dataset.id
        else
            @_internalTaskCounter += 1
            t.internalId = 'CNE_task_id_' + @_internalTaskCounter
            @_stackTaskChange(t,'created')
            lineDiv.dataset.id = t.internalId
        return t


    ###* -----------------------------------------------------------------------
     * Called only by readHtml() (called by setEditorContent() and undo/redo)
     * When an html is loaded by readHtml(), if a line corresponds to a task, we
     * must find if the model of the task line already exists. If yes, link it
     * to the lineDiv, otherwiser fetch if from server.
     * @param {Element} lineDiv The lineDiv turned into a task.
    ###
    _setTaskToLine : (lineDiv) ->
        # console.info '=== _setTaskToLine'

        # Add btn listener
        btn = lineDiv.firstChild
        btn.addEventListener('click', @_toggleTaskCB)

        # try to find if a model already exists  for this task, what is highly
        # especially possible when readHtml has been called during an undo()
        id = lineDiv.dataset.id
        for t in @_taskList
            if t.internalId == id
                lineDiv.task = t
                t.lineDiv = lineDiv
                return true

        # if the id stored in the hmtml line is a temporary id and that there is
        # task localy with this temporary id, then it's a rare case (can
        # happen if the html of the editor is saved and closed before the task
        # has its final id). We choose in this case to create the task.
        if id.slice(0,12) == 'CNE_task_id_'
            @_createTaskForLine(lineDiv)
            @editorTarget$.trigger jQuery.Event('onChange')

        else
            # console.info 'fetch requested with id', id
            t = new Task(id:id)
            @_internalTaskCounter += 1
            t.internalId = 'CNE_task_id_' + @_internalTaskCounter
            lineDiv.task = t
            lineDiv.dataset.id = t.internalId
            t.lineDiv = lineDiv
            t.fetch(silent:true)
            .done () =>
                # console.info "editor : t.fetch.done()",t.id
                t.isFromServer = true
                realtimer.watchOne t
                @_updateTaskLine(t) #task may have change when note was not open

            .fail (resp) =>
                # console.info "editor : t.fetch.fail()",t.id
                # fetch was not possible, there are 2 possible causes :
                #   1/ the task has been deleted in the meanwhile turn lineDiv
                #   in a line
                if resp.status == 404
                    @_turneTaskIntoLine(t.lineDiv)
                #   2/ the todo server is not responding, store task state in
                #   the model so that a reverse can be done if task is modified
                #   by the user and the todo server still doesn't answer.
                else
                    t.set(  \
                        {
                            done       :t.lineDiv.dataset.state == 'done' ,
                            description:t.lineDiv.firstChild.nextSibling.textContent
                        }
                    ,
                        {silent:true}
                    )
                    t.isFromServer = false

            t.on 'change', (t)=>
                # console.info ' editor : change from fetch detected !', t.id
                # console.info t.changedAttributes()
                t.isFromServer = true
                @_updateTaskLine(t)

            t.on 'destroy', (t)=>
                # console.info ' editor : destroy from fetch detected !', t.id
                @_turneTaskIntoLine(t.lineDiv)

            @_taskList.push(t)

        return true


    ###* -----------------------------------------------------------------------
     * update a line div of a task with the attributes values of a model.
     * It uses the model previous attributes values if isRevert == true
     * @param  {Model}  t        A task backbone model
     * @param  {Boolean} isRevert If True, it will use previous attributes
     *                            values instead of its current values.
    ###
    _updateTaskLine : (t, isRevert) ->
        # if @_isTaskUnchanged(t)
        #     return
        if isRevert
            attrib = t.previousAttributes()
        else
            attrib = t.attributes
        console.info attrib
        t.lineDiv.firstChild.nextSibling.textContent = attrib.description
        currentTaskState = t.lineDiv.dataset.state == 'done'
        if attrib.done
            newState = 'done'
        else
            newState = 'undone'
        if currentTaskState != newState
            t.lineDiv.dataset.state = newState
        return true



    _stackTaskChange : (task,action) ->
        # action in : done, undone, modified, removed
        console.info '== editor._stackTaskChange() ' + action, task.internalId

        @_stackTaskForSave(task.internalId, task, action)

        switch action

            when 'modified', 'done', 'undone'
                @_tasksModifSinceLastHistory[task.internalId] =
                    t:task, a:'modified'
                # console.info '  @_tasksModifSinceLastHistory',
                #  @_tasksModifSinceLastHistory

            when 'created'
                @_tasksModifSinceLastHistory[task.internalId] =
                    t:task, a:'created'

            # when 'removed'
            #   nothing

        @__printTasksModifStacks()

        return true


    ###* -----------------------------------------------------------------------
     * When a task is modified or a undo/redo has modified its state, this
     * function stacks the information so that when a save is triggered, then we
     * know which task to save.
     * @param  {string} id     The internal id of the task
     * @param  {Task} t      The task model concerned
     * @param  {String} action 'modified', 'done', 'undone', 'created', 'deleted'
     *                         or 'removed'
    ###
    _stackTaskForSave : (id, t, action) ->

        modif = @_tasksToBeSaved[id]
        if !@_tasksToBeSaved[id]
            modif = t:t
            @_tasksToBeSaved[id] = modif

        switch action
            when 'modified', 'done', 'undone'
                modif.modified = true
            when 'created'
                if modif.deleted
                    modif.deleted  = false
                    modif.created  = false
                    modif.modified = true
                else
                    modif.created = true
            when 'deleted'
                if modif.created
                    modif.deleted = false
                    modif.created = false
                else
                    modif.deleted = true
            when 'removed'
                 modif.removed = true

        return true


    ###* -----------------------------------------------------------------------
     * Saves the creations/modification/deletion not yet saved.
     * a modif can b
     * modif.removed | 1 1 1 1 1 1 1 1 | 0 0 | 0 0 | 0 | 0 0 | 0
     * modif.created | 1 1 1 1 0 0 0 0 | 1 1 | 0 0 | 0 | 1 1 | 0
     * modif.modified| 1 1 0 0 1 1 0 0 | 1 0 | 1 0 | 1 | 1 0 | 0
     * modif.deleted | 1 0 1 0 1 0 1 0 | 1 1 | 1 1 | 0 | 0 0 | 0
     * modif.action  | N N N N N N N N | N N | D D | M | C C | N
     * (N D C = Nothing, Create, Delete)
     * @return {[type]} [description]
    ###
    saveTasks : () ->
        console.info '== saveTasks()'

        for id,modif of @_tasksToBeSaved
            # console.info 'saveTask
            if modif.deleted
                modif.t.destroy(silent: true)

            else if modif.created && modif.deleted
                continue

            else if modif.removed
                continue

            else if modif.modified && !modif.created
                t = modif.t
                l = t.lineDiv
                t.save({
                        done        : (l.dataset.state == 'done')
                        description :  l.textContent.slice(1)
                    },{
                        ignoreMySocketNotification: true
                        silent: true
                        error : (t) =>
                            window.alert('Cozy Todo is not responding, save ' +\
                                'of tasks is not possible so we cancel '      +\
                                'modifications.')
                            @_updateTaskLine(t, true)
                    }
                )
                t.isFromServer = false

            else if modif.created && !modif.t.id
                @_saveTaskCreation(modif.t)

            # case of a task re-created by an undo
            else if modif.created && modif.t.id
                # remove previou model from _taskList :
                i = @_taskList
                for t,i in @_taskList
                    if t.internalId == id
                        @_taskList.splice(i,1)
                        break
                # create the new task model :
                lineDiv = @linesDiv.querySelectorAll(
                    "div[data-id='#{modif.t.internalId}']")[0]
                t = @_createTaskForLine(lineDiv,true)
                modif.t = t
                @_replaceInTaskHistory(t)
                @_saveTaskCreation(t)

        @_tasksToBeSaved = {}



    _saveTaskCreation : (t) ->
        l = t.lineDiv
        t.save({
                done        : (l.dataset.state == 'done')
                description :  l.textContent.slice(1)
               },
               {
                ignoreMySocketNotification: true
                silent  : true
                success : (t) =>
                    # console.info "editor t.save.done()",t.id
                    realtimer.watchOne t

                    # t.lineDiv.dataset.id = t.internalId
                    @editorTarget$.trigger jQuery.Event('onChange')

                    t.lineDiv.dataset.id = t.id

                    # will be called by modification on server side.
                    # Modifications initiated on this client will be
                    # saved with silent=true so that this call back is
                    # not fired whereas ui is uptodate
                    t.on 'change', () =>
                        # console.info "onchange from save", t.id
                        # console.info t.changedAttributes()
                        t.isFromServer = true
                        @_updateTaskLine(t)
                    t.on 'destroy', (t) =>
                        # console.info ' editor : destroy from save',t.id
                        @_turneTaskIntoLine(t.lineDiv)
                error : (t) =>
                    window.alert('Cozy Todo is not responding, save ' +\
                        'of tasks is not possible so we cancel '      +\
                        'the task creation.')
                    @_turneTaskIntoLine(t.lineDiv)
                }
        )
        t.isFromServer = false


    ###* -----------------------------------------------------------------------
     * Tests if there is a modification between the model and the lineDiv
     * @param  {[type]}  task [description]
     * @return {Boolean}      [description]
    ###
    _isTaskUnchanged : (task) ->
        res = true
        line = task.lineDiv
        res = res && task.get('done') == (line.dataset.state == 'done')
        res = res && task.get('description') == line.textContent.slice(1)
        return res


    ###* -----------------------------------------------------------------------
     * Returns true if the selection is at the start of a word. Ex :
     *     . xxxx |yyyy   : true
     *     . xxxx | yyyy  : true
     *     . |yyyy        : true
     *     . xxxx y|yyyy  : false
     *     . xxxx| yyyy   : false
     * @return {Boolean} True if the selection starts at the beginning of a word
    ###
    _isStartingWord  : () ->
        sel = @updateCurrentSelIsStartIsEnd()
        rg = sel.theoricalRange

        # if selection is at the start of the line
        if sel.rangeIsStartLine
            return true

        # else find the caracter just before the start of the selection
        else
            # if the selection is at the beginning of a the text node (since
            # normalized, startContainer is in a text node), we get all the text
            # that is befor the selection
            if rg.startOffset == 0
                rg2 = rg.cloneRange()
                rg2.collapse()
                rg2.setStart(selection._getLineDiv(rg2.startContainer), 0)
                txt = rg2.toString()
                if txt.length == 0
                    # we are not at the beginning of the line but there is no
                    # text before : means there is a non textual segment embeded
                    # in the line, for instance an image without space character
                    # after it : we consider that this is the start of a word,
                    # but this is not obvious.
                    return true
                else
                    char = text.slice(-1)
            else
                char = rg.startContainer.textContent.substr(rg.startOffset-1, 1)

            # check that the caracter preceding the selection is a space or a
            # non breakable space
            if char.charCodeAt(0) == 32 or char.charCodeAt(0) == 160
                return true
            else
                return false



    getCurrentAllowedInsertions : () ->
        sel = @updateCurrentSel()
        if sel.startLineDiv.dataset.type == 'task'
            return []
            # return ['contact','event','reminder','htag']
        else
            return ['todo']
            # return ['contact','todo','event','reminder','htag']


    ### ------------------------------------------------------------------------
    # EXTENSION : _updateDeepest
    #
    # Find the maximal deep (thus the deepest line) of the text
    # TODO: improve it so it only calculates the new depth from the modified
    #       lines (not all of them)
    # TODO: set a class system rather than multiple CSS files. Thus titles
    #       classes look like "Th-n depth3" for instance if max depth is 3
    # note: These todos arent our priority for now
    ###
    _updateDeepest : () ->
        max = 1
        lines = @_lines
        for c of lines
            if @editorBody$.children("#" + "#{lines[c].lineID}").length > 0 and
               lines[c].lineType == "Th" and lines[c].lineDepthAbs > max
                max = @_lines[c].lineDepthAbs

        # Following code is way too ugly to be kept
        # It needs to be replaced with a way to change a variable in a styl or
        # css file... but I don't even know if it is possible.
        if max != @_deepest
            @_deepest = max
            if max < 4
                @replaceCSS("stylesheets/app-deep-#{max}.css")
            else
                @replaceCSS("stylesheets/app-deep-4.css")


    ###* -----------------------------------------------------------------------
     * Initialize the editor content from a html string
     * The html string should not been pretified because of the spaces and
     * charriage return.
     * If unPretify = true then a regex tries to set up things
    ###
    replaceContent : (htmlString, unPretify) ->

        if unPretify
            htmlString = htmlString.replace(/>[\n ]*</g, "><")

        if @.isUrlPopoverOn
            @_cancelUrlPopover(false)

        @linesDiv.innerHTML = htmlString
        @_taskList = []
        @_readHtml()
        @_setCaret(@linesDiv.firstChild.firstChild, 0, true)
        @newPosition = true
        @hotString = ''
        # @_initHistory()


    ### ------------------------------------------------------------------------
    # Clear editor content
    ###
    deleteContent : ->
        emptyLine = '<div id="CNID_1" class="Tu-1"><span></span><br></div>'
        @replaceContent(emptyLine)


    ### ------------------------------------------------------------------------
    # Returns an html string representing the editor content
    ###
    getEditorContent : () ->
        if @_hotString.isPreparing or @.isUrlPopoverOn
            clone = @linesDiv.cloneNode(true)

            # if the auto completion of hot string is visible : remove it
            if @_hotString.isPreparing
                segment = clone.querySelector('.CNE_hot_string')
                segment.classList.remove('CNE_hot_string')
                lineDiv = segment.parentElement
                segment.textContent = ''
                @_fusionSimilarSegments(lineDiv, [])
                segment = clone.querySelector('#CNE_autocomplete')
                segment.parentElement.removeChild(segment)

            # if the urlpopover is visible : remove it
            if  @.isUrlPopoverOn
                # remove the url popover
                segment = clone.querySelector('#CNE_urlPopover')
                segment.parentElement.removeChild(segment)
                # remove the style of the selected segments
                segments = clone.querySelectorAll('.CNE_url_in_edition')
                for seg in segments
                    seg.classList.remove('CNE_url_in_edition')
                # if the link were created, remove them
                if @urlPopover.isLinkCreation
                    lineDiv = selection._getLineDiv(segments[0])
                    for seg in segments
                        @_applyAhrefToSegments(seg, seg , [], false, '')
                    @_fusionSimilarSegments(lineDiv,[])

            txt = clone.innerHTML

        else
            txt = @linesDiv.innerHTML

        return txt


    ### ------------------------------------------------------------------------
    # Sets the editor content from a markdown string
    ###
    setEditorContent : (htmlContent) ->
        @replaceContent(htmlContent)


    ### ------------------------------------------------------------------------
    # DEPRECATED - USED ONLY FOR REVERSE COMPATIBILITY
    # Sets the editor content from a markdown string
    ###
    setEditorContentFromMD : (mdContent) ->
        cozyContent = md2cozy.md2cozy mdContent
        @replaceContent(cozyContent)


    ### ------------------------------------------------------------------------
    # Change the path of the css applied to the editor iframe
    ###
    replaceCSS : (path) ->
        document = @document
        linkElm = document.querySelector('#editorCSS')
        linkElm.setAttribute('href' , path)
        document.head.appendChild(linkElm)


    ###* -----------------------------------------------------------------------
     * Return [metaKeyCode,keyCode] corresponding to the key strike combinaison.
     * the string structure = [meta key]-[key]
     *   * [metaKeyCode] : (Alt)*(Ctrl)*(Shift)*
     *   * [keyCode] : (return|end|...|A|S|V|Y|Z)|(other)
     * ex :
     *   * "AltShift" & "up"
     *   * "AltCtrl" & "down"
     *   * "Shift" & "A"
     *   * "Ctrl" & "S"
     *   * "" & "other"
     * @param  {[type]} e [description]
     * @return {[type]}   [description]
    ###
    getShortCut : (e) ->
        metaKey = `(e.altKey ? "Alt" : "") +
                              (e.ctrlKey ? "Ctrl" : "") +
                              (e.shiftKey ? "Shift" : "")`

        keyCode = e.keyCode
        switch keyCode
            when 13 then key = 'return'    ; isAction = true
            when 16 then key = 'shift'     ; isAction = true
            when 17 then key = 'ctrl'      ; isAction = true
            when 18 then key = 'alt'       ; isAction = true
            when 35 then key = 'end'       ; isAction = true
            when 36 then key = 'home'      ; isAction = true
            when 33 then key = 'pgUp'      ; isAction = true
            when 34 then key = 'pgDwn'     ; isAction = true
            when 37 then key = 'left'      ; isAction = true
            when 38 then key = 'up'        ; isAction = true
            when 39 then key = 'right'     ; isAction = true
            when 40 then key = 'down'      ; isAction = true
            when 9  then key = 'tab'       ; isAction = true
            when 8  then key = 'backspace' ; isAction = true
            when 32 then key = 'space'     ; isAction = true
            when 27 then key = 'esc'       ; isAction = true
            when 46 then key = 'suppr'     ; isAction = true
            else
                isAction = false
                keyCode = e.which
                switch keyCode
                    when 32 then key = 'space'
                    when 8  then key = 'backspace'
                    when 65 then key = 'A'
                    when 66 then key = 'B'
                    when 85 then key = 'U'
                    when 75 then key = 'K'
                    when 76 then key = 'L'
                    when 83 then key = 'S'
                    when 86 then key = 'V'
                    when 89 then key = 'Y'
                    when 90 then key = 'Z'
                    else
                        key = 'other'

        shortcut = metaKey + '-' + key

        # a,s,v,y,z alone are simple characters
        if metaKey in ['', 'Shift'] && key in
             ['A', 'B', 'U', 'K', 'L', 'S', 'V', 'Y', 'Z']
            key = 'other'

        @_shortcut =
            meta     : metaKey
            key      : key
            isAction : isAction
            shortcut : shortcut
            keyCode  : keyCode
        # console.info 'editor.getShortCut()', @_shortcut.shortcut


    ###* -----------------------------------------------------------------------
     * Callback to be used in production.
     * In case of error thrown by the editor, we catch it and undo the content
     * to avoid to loose data.
     * @param  {event} e  The key event
    ###
    _keyDownCbTry : (e) =>
        # try actions, in case of error, undo
        try
            @_keyDownCb(e)
        catch error
            alert('A bug occured, we prefer to undo your last action not ' + \
                  'to take any risk.\n\nMessage :\n' + error)
            e.preventDefault()
            @unDo()


    ###* -----------------------------------------------------------------------
     * Change the callback called by keydown event for the "test" callback.
     * The aim is that during test we don't want to intercept errors so that
     * the test can detect the error.
    ###
    registerKeyDownCbForTest : ()=>
        @linesDiv.removeEventListener('keydown', @_keyDownCbTry, true)
        # otherwise _unRegisterEventListeners will no longer work
        @_keyDownCbTry = @_keyDownCb
        @linesDiv.addEventListener('keydown', @_keyDownCbTry, true)


    ###*------------------------------------------------------------------------
     *
     * The listener of keyPress event on the editor's iframe... the king !
     *
     * Params :
     * e : the event object. Interesting attributes :
     *   .which
     *   .altKey
     *   .ctrlKey
     *   .metaKey
     *   .shiftKey
     *   .keyCode
     *
     * SHORTCUT
     *
     * Definition of a shortcut :
     *   a combination alt,ctrl,shift,meta
     *   + one caracter(.which)
     *   or
     *     arrow (.keyCode=dghb:) or
     *     return(keyCode:13) or
     *     bckspace (which:8) or
     *     tab(keyCode:9)
     *   ex : shortcut = 'CtrlShift-up', 'Ctrl-115' (ctrl+s), '-115' (s),
     *                   'Ctrl-'
    ###
    _keyDownCb : (e) =>
        # console.info '_keyDownCb'
        if ! @isEnabled
            return true

        # 1- Prepare the shortcut corresponding to pressed keys
        @getShortCut(e)
        shortcut = @_shortcut.shortcut

        # 2- Add a new history step if the short cut is different from previous
        # shortcut and only in case a a return, a backspace, a space...
        # This means that in case of multiple return, only the first one is in
        # history. A letter such as 'a' doesn't increase the history.

        # console.info '== keyDownCb() : shortcut', shortcut, '_lastKey', @_lastKey, 'isAction', @_shortcut.isAction, 'newPosition', @newPosition
        # if @_lastKey != shortcut and \
        #        shortcut in ['-return', '-backspace', '-suppr',
        #                     'CtrlShift-down', 'CtrlShift-up',
        #                     'CtrlShift-left', 'CtrlShift-right',
        #                     'Ctrl-V']
        #     console.info 'cas1'
        #     @_addHistory()

        # else if @_lastKey == '-space' && shortcut != '-space'
        #     console.info 'cas2'
        #     @_addHistory()

        # else if @newPosition and !@_shortcut.isAction and shortcut != 'Ctrl-Y' and shortcut != 'Ctrl-Z'
        #     console.info 'cas3'
        #     @_addHistory()

        lastShortcut = @_lastKey
        @_lastKey = shortcut

        @currentSel =
            sel              : null
            range            : null
            startLine        : null
            endLine          : null
            rangeIsStartLine : null
            rangeIsEndLine   : null
            startBP          : null
            endBP            : null


        # 3- Manage the newPosition flag
        #    newPosition == true if the position of caret or selection has been
        #    modified with keyboard or mouse.
        #    If newPosition == true and a character is typed or a suppression
        #    key is pressed, then selection must be "normalized" so that its
        #    break points are in text nodes. Normalization is done by
        #    updateCurrentSel or updateCurrentSelIsStartIsEnd that is chosen
        #    before to run the action corresponding to the shorcut.
        #    The update of @newPosition is done :
        #       - bellow depending on the key stroke
        #       - in _mouseupCb
        #

        # 4- Give hand to the hotString manager if this one is preparing one.
        # if the hotString manager launched an action, the stop here and prevent
        # any other action of the editor.
        if @_hotString.isPreparing
            if @_hotString.keyDownCb(shortcut)
                e.preventDefault()
                return false

        # 5- if a shift keydown : prevent the partial selection of tag by setting
        # all of them uneditable in case where this happens outside of a tag.
        if e.keyCode == 16
            rg = this.document.getSelection().getRangeAt(0)
            if !selection.getSegment(rg.startContainer,0).dataset.type
                @Tags.setTagUnEditable()

        # 6- Manage "simple keys" (letters, arrows & alike, with or without
        # shift but without alt and ctrl (CtrlSthift allowed for arrows & alike)
        switch @_shortcut.key

            when 'up', 'down', 'left', 'right', 'pgUp', 'pgDwn', 'end', 'home'
                if !e.altKey && (e.shiftKey or (!e.shiftKey && !e.ctrlrlKey) )
                    @newPosition = true
                    return true

            when 'other', 'space'
                if !e.ctrlrlKey && !e.altKey
                    if @newPosition
                        @_addHistory()
                    else if lastShortcut == '-space' && shortcut != '-space'
                        @_addHistory()

                    if @newPosition
                        sel = @updateCurrentSel()
                        if ! sel.theoricalRange.collapsed
                            @_backspace()
                        @newPosition = false
                    @editorTarget$.trigger jQuery.Event('onChange')
                    @_detectTaskChange()
                    return true
                if e.ctrlKey && e.altKey # altgr on windows
                    return true


        # 7- if alt or ctrl is pressed, then prevent default, only custom
        # behaviour defined below must occur, no default by browser.
        if e.altKey or e.ctrlKey
            unless e.altKey && e.ctrlKey
                e.preventDefault()

        # 8- launch the action corresponding to the pressed shortcut
        # If a popover is visible, the actions are sent to it
        switch shortcut

            when '-return'
                @_addHistory() if lastShortcut != shortcut
                @updateCurrentSelIsStartIsEnd()
                if @currentSel.isStartInTask and lastShortcut == shortcut
                    @_addHistory()
                @_return()
                @newPosition = false
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when '-backspace'
                @_addHistory() if lastShortcut != shortcut
                @updateCurrentSelIsStartIsEnd()
                @_backspace()
                # important, for instance in the case of a deletion of a range
                # within a single line
                @newPosition = true
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when '-tab'
                @_addHistory()
                @tab()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when 'Shift-tab'
                @_addHistory()
                @shiftTab()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when '-suppr'
                @_addHistory() if lastShortcut != shortcut
                @updateCurrentSelIsStartIsEnd()
                @_suppr(e)
                e.preventDefault()
                @newPosition = true
                @editorTarget$.trigger jQuery.Event('onChange')

            when 'CtrlShift-down'
                @_addHistory() if lastShortcut != shortcut
                # @_moveLinesDown()
                e.preventDefault()

            when 'CtrlShift-up'
                @_addHistory() if lastShortcut != shortcut
                # @_moveLinesUp()
                e.preventDefault()

            when 'Ctrl-A'
                selection.selectAll(this)
                e.preventDefault()

            when 'Alt-L'
                @_addHistory()
                @markerList()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when 'Alt-A'
                @_addHistory()
                @toggleType()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when 'Ctrl-V'
                @_addHistory()
                @editorTarget$.trigger jQuery.Event('onChange')
                return true

            when 'Ctrl-B'
                @_addHistory()
                @strong()
                e.preventDefault()

            # when 'Ctrl-U'
            #     @underline()
            #     e.preventDefault()
            #     @editorTarget$.trigger jQuery.Event('onChange')

            when 'Ctrl-K'
                @linkifySelection()
                e.preventDefault()

            when 'Ctrl-S'
                @editorTarget$.trigger jQuery.Event('saveRequest')
                e.preventDefault()
                e.stopPropagation()

            when 'Ctrl-Z'
                @unDo()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            when 'Ctrl-Y'
                @reDo()
                e.preventDefault()
                @editorTarget$.trigger jQuery.Event('onChange')

            else
                # console.info 'keyDownCb ELSE'
                e.preventDefault()



    _keypressCb : (e) =>
        @_hotString.keypressCb(e)




    ###* -----------------------------------------------------------------------
     * Detects where the carret is after a keyup in order to launch required
     * actions :
     * A/ correct the 2 following problems :
     *   a- in Chrome, the insertion of a caracter by the browser may be out of
     *   a span.
     *   This is du to a bug in Chrome : you can create a range with its start
     *   break point in an empty span. But if you add this range to the
     *   selection, then this latter will not respect your range and its start
     *   break point will be outside the range. When a key is pressed to insert
     *   a caracter, the browser inserts it at the start break point, ie outside
     *   the span... this function detects after each keyup is there is a text
     *   node outside a span and move its content and the carret.
     *   b- in order to keep the navigation with arrows working, we have to
     *   insert a text in the buttons of tasks. That's why we have to remove the
     *   carret from the button when the browser put it in a button.
     * B/ edit meta data
     * C/ Deal case when the selection has been changed with keyboard
     * D/ Deal hot string.
     * E/ Fire the editor onKeyUp event
     * @param  {Event} e The key event
    ###
    _keyupCb : (e) =>

        # A/a) If chrome, place last inserted caracter in the correct segment.
        if @isChromeOrSafari
            @_chromeCorrection()

        # A/ Detect in which segment the caret is and launch adapted actions
        rg = this.document.getSelection().getRangeAt(0)
        startSeg = selection.getSegment(rg.startContainer)
        endSeg   = selection.getSegment(rg.endContainer)
        if startSeg.dataset
            switch startSeg.dataset.type

                # A/b) Remove carret from tasks buttons.
                when 'taskBtn'
                    # if left : go to the end of previous line.
                    if e.keyCode == 37
                        line = selection.getLineDiv(startSeg,0).previousSibling
                        if line
                            newCont = line.lastChild.previousSibling
                            @_setCaret(newCont,newCont.childNodes.length)
                        else
                            @_setCaret(startSeg.nextSibling,0)
                    # put it at the beginning of the text of the task
                    else
                        @_setCaret(startSeg.nextSibling,0)

                # B/ When in a meta segment (contact, reminder etc...), edit it.
                when 'contact', 'reminder', 'htag'
                    if !@_hotString.isPreparing
                        @Tags.remove(startSeg)
                        @_hotString.edit(startSeg,rg)

        # C/ shift Keyup : a selection with keyboard might occured
        if e.keyCode == 16
            # 1- setTags as editable again.
            @Tags.setTagEditable()
            # 2- if selection has an end which is a tag (hoString, reminder,
            # contact...) but not the other, then put all the selection within the
            # tag.
            if (startSeg.dataset.type && !endSeg.dataset.type)
                @setSelection(rg.startContainer, rg.startOffset,
                              startSeg         , startSeg.childNodes.length)
                endSeg = startSeg
            else if (!startSeg.dataset.type && endSeg.dataset.type)
                @setSelection(endSeg         , 0 ,
                              rg.endContainer, rg.endOffset)
                startSeg = endSeg
            # 3- if hotstring is preparing but the selection is no longer in the
            # hotString segment : reset hotString.
            if @_hotString.isPreparing and startSeg != @_hotString._hsSegment
                @_hotString.reset('current')

        # D/ If a hot string is preparing, check selection is still in it.
        #    If yes, update the hotstring, otherwise cancel hotstring.
        if @_hotString.isPreparing
            # if autoToBeShowed then showAutoAndHighLight
            if @_hotString._autoToBeShowed
                @_hotString.showAutoAndHighLight()
            # else if a selection is on progress (a left, right,up, down,begin,end,
            # pageup,pagedwn & ctrl while shift key is pressed) then do nothing.
            else if !(e.shiftKey and e.keyCode in [17,37,38,36,33,40,39,34,35])
                if startSeg == @_hotString._hsSegment
                    @_hotString.updateHs()
                else
                    @_hotString.updateHs()
                    @_hotString.reset('current')

        # E/ Fire the editor onKeyUp event
        switch @_shortcut.shortcut
            when 'Ctrl-S', 'Ctrl-other'
                return
        @editorTarget$.trigger jQuery.Event("onKeyUp")

        return true




    ###*
     *   In Chrome, the insertion of a caracter by the browser may be out of
     *   a span.
     *   This is du to a bug in Chrome : you can create a range with its start
     *   break point in an empty span. But if you add this range to the
     *   selection, then this latter will not respect your range and its start
     *   break point will be outside the range. When a key is pressed to insert
     *   a caracter, the browser inserts it at the start break point, ie outside
     *   the span... this function detects after each keyup is there is a text
     *   node outside a span and move its content and the carret.
    ###
    _chromeCorrection : () ->
        # loop on all elements of the div of the line. If there are textnodes,
        # insert them in the previous span, if none, to the next, if none create
        # one. Then delete the textnode.
        curSel = @updateCurrentSel()
        line   = curSel.startLine.line$[0]
        nodes  = line.childNodes
        l = nodes.length
        i = 0
        # the final <br/> may be deleted by chrome : if so : add it.
        if nodes[l-1].nodeName != 'BR'
            brNode = document.createElement('br')
            line.appendChild(brNode)
        # loop on line's children to find the possible '#text'
        while i < l
            node = nodes[i]
            if node.nodeName == '#text'
                t = node.textContent
                prevSeg = selection.getPrevSegment(node)
                if prevSeg
                    if prevSeg.nodeName in ['SPAN','A']
                        prevSeg.textContent += t
                        @_setCaret(prevSeg,prevSeg.childNodes.length)
                        line.removeChild(node)
                        l -= 1
                    else
                        throw new Error('A line should be constituted of
                            only <span> and <a>')
                else
                    nextSeg = selection.getNextSegment(node)
                    if nextSeg
                        if nextSeg.nodeName in ['SPAN','A', '#text']
                            nextSeg.textContent = t + nextSeg.textContent
                            @_setCaret(nextSeg.firstChild,t.length)
                            line.removeChild(node)
                            l -= 1
                        else if nextSeg.nodeName in ['#text']
                            nextSeg.textContent = t + nextSeg.textContent
                            @_setCaret(nextSeg,t.length)
                            line.removeChild(node)
                            l -= 1
                        else
                            throw new Error('A line should be constituted of
                                only <span> and <a>')
                    else # if there is no nextSeg, create one.
                        newSpan = document.createElement('span')
                        newSpan.textContent = t
                        line.replaceChild(newSpan,node)
                        @_setCaret(newSpan.firstChild,t.length)
                        i += 1
            else
                i += 1

        return true



    ###* -----------------------------------------------------------------------
     * updates @currentSel =
            sel              : {Selection} of the editor's document
            range            : sel.getRangeAt(0)
            startLine        : the 1st line of the current selection
            endLine          : the last line of the current selection
            startLineDiv     : the element corresponding to startLine
            endLineDiv       : the element corresponding to endLine
            isStartInTask    : {Boolean} True if the startLine is a task
            rangeIsStartLine : {boolean} true if the selection ends at
                               the end of its line : NOT UPDATE HERE - see
                               updateCurrentSelIsStartIsEnd
            rangeIsEndLine   : {boolean} true if the selection starts at
                               the start of its line : NOT UPDATE HERE - see
                               updateCurrentSelIsStartIsEnd
            theoricalRange   : theoricalRange : normalization of the selection
                               should put each break points in a node text. It
                               doesn't work in chrome due to a bug. We therefore
                               store here the "theorical range" that the
                               selection should match. It means that if you are
                               not in chrome this is equal to range.
       If the caret position has just changed (@newPosition == true) then we
       normalise the selection (put its break points in text nodes)
       We also normalize if in Chrome because in order to have a range wit
       break points in text nodes.
     * @return {object} @currentSel
    ###
    updateCurrentSel : () ->

        # get the current range and normalize it
        sel = @getEditorSelection()
        range = sel.getRangeAt(0)

        # normalize if carret has been moved or if we are in Chrome
        if @newPosition or @isChromeOrSafari
            [newStartBP, newEndBP] = selection.normalize(range)
            theoricalRange = document.createRange()
            theoricalRange.setStart(newStartBP.cont,newStartBP.offset)
            theoricalRange.setEnd(newEndBP.cont,newEndBP.offset)
        else
            theoricalRange = range

        # get the lines corresponding to the range :
        startLineDiv = selection.getLineDiv(range.startContainer)
        endLineDiv   = selection.getLineDiv(range.endContainer  )
        startLine = @_lines[startLineDiv.id]
        endLine   = @_lines[endLineDiv.id]
        isStartInTask = startLineDiv.dataset.type == 'task'

        # upadte
        @currentSel =
            sel              : sel
            range            : range
            startLineDiv     : startLineDiv
            endLineDiv       : endLineDiv
            isStartInTask    : isStartInTask
            startLine        : startLine
            endLine          : endLine
            rangeIsStartLine : null
            rangeIsEndLine   : null
            theoricalRange   : theoricalRange

        return @currentSel


    ###* -----------------------------------------------------------------------
     * updates @currentSel and check if range is at the start of begin of the
     * corresponding line.
     * @currentSel =
            sel              : {Selection} of the editor's document
            range            : sel.getRangeAt(0)
            startLine        : the 1st line of the current selection
            endLine          : the last line of the current selection
            startLineDiv     : the element corresponding to startLine
            endLineDiv       : the element corresponding to endLine
            isStartInTask    : {Boolean} True if the startLine is a task
            rangeIsStartLine : {boolean} true if the selection ends at
                               the end of its line.
            rangeIsEndLine   : {boolean} true if the selection starts at
                               the start of its line.
            theoricalRange   : theoricalRange : normalization of the selection
                               should put each break points in a node text. It
                               doesn't work in chrome due to a bug. We therefore
                               store here the "theorical range" that the
                               selection should match. It means that if you are
                               not in chrome this is equal to range.
       If the caret position has just changed (@newPosition == true) then we
       normalise the selection (put its break points in text nodes)
       We also normalize if in Chrome because in order to have a range wit
       break points in text nodes.
     * @return {object} @currentSel
    ###
    updateCurrentSelIsStartIsEnd : () ->
        sel                = @getEditorSelection()
        range              = sel.getRangeAt(0)

        # normalize if carret has been moved or if we are in Chrome
        if @newPosition or @isChromeOrSafari
            [newStartBP, newEndBP] = selection.normalize(range)
            theoricalRange = document.createRange()
            theoricalRange.setStart(newStartBP.cont,newStartBP.offset)
            theoricalRange.setEnd(newEndBP.cont,newEndBP.offset)
        else
            theoricalRange = range

        startContainer     = range.startContainer
        endContainer       = range.endContainer
        initialStartOffset = range.startOffset
        initialEndOffset   = range.endOffset

        # find startLine and the rangeIsStartLine
        {div,isStart,isEnd} = selection.getLineDivIsStartIsEnd(
                                            startContainer, initialStartOffset)
        startDiv         = div
        startLine        = @_lines[startDiv.id]
        rangeIsStartLine = isStart
        firstLineIsEnd   = isEnd
        isStartInTask    = startDiv.dataset.type == 'task'

        # find endLine and the rangeIsEndLine
        {div,isStart,isEnd,} = selection.getLineDivIsStartIsEnd(
                                            endContainer, initialEndOffset)
        endDiv          = div
        endLine         = @_lines[endDiv.id]
        rangeIsEndLine  = isEnd
        lastLineIsStart = isStart

        # result
        @currentSel =
            sel              : sel
            range            : range
            startLineDiv     : startDiv
            endLineDiv       : endDiv
            isStartInTask    : isStartInTask
            startLine        : startLine
            endLine          : endLine
            rangeIsStartLine : rangeIsStartLine
            rangeIsEndLine   : rangeIsEndLine
            firstLineIsEnd   : firstLineIsEnd
            lastLineIsStart  : lastLineIsStart
            theoricalRange   : theoricalRange

        return @currentSel



    ###* -----------------------------------------------------------------------
     * Check if the first range of the selection is NOT in the editor
     * @param  {Boolean}  expectWide [optional] If true, tests if the first
     *                               range of the selection is collapsed. If it
     *                               is the case, then return false
     * @return {Boolean} True if there is a selection, false otherwise.
    ###
    hasNoSelection : (expectWide) ->
        sel = this.document.getSelection()
        if sel.rangeCount > 0
            rg = sel.getRangeAt(0)

            if expectWide and rg.collapsed
                return true

            cont = rg.startContainer
            while cont != null
                if cont == @linesDiv
                    break
                cont = cont.parentNode
            if cont == null
                return true

            cont = rg.endContainer
            while cont == null
                if cont == @linesDiv
                    return false
                cont = cont.parentNode
            if cont == null
                return true
        else
            return true


    ###* -----------------------------------------------------------------------
     * Put a strong (bold) css class on the selection of the editor.
     * History is incremented before action and focus is set on the editor.
     * @return {[type]} [description]
    ###
    strong : () ->
        if !@isEnabled or @hasNoSelection(true) or @_hotString.isPreparing
            return true
        @._addHistory()
        rg = @._applyMetaDataOnSelection('CNE_strong')
        if !rg
            @._removeLastHistoryStep()
        else
            @editorTarget$.trigger jQuery.Event('onChange')



    underline : () ->
        if ! @isEnabled or @hasNoSelection(true) or @_hotString.isPreparing
            return true
        @._addHistory()
        rg = @._applyMetaDataOnSelection('CNE_underline')
        if !rg
            @._removeLastHistoryStep()
        else
            @editorTarget$.trigger jQuery.Event('onChange')



    linkifySelection: () ->
        if ! @isEnabled or @hasNoSelection() or @_hotString.isPreparing
            return true

        currentSel = @updateCurrentSelIsStartIsEnd()

        # if we are in a task, don't allow link creation
        return true if currentSel.isStartInTask

        range = currentSel.theoricalRange


        # Show url popover if range is collapsed in a link segment
        if range.collapsed
            segments = @_getLinkSegments()
            if segments
                @_showUrlPopover(segments,false)

        # if selection is not collapsed, 2 cases :
        # the start breakpoint is in a link or not
        else
            segments = @_getLinkSegments()
            # case when the start break point is in a link
            if segments
                @_showUrlPopover(segments,false)
            # case when the start break point is not in a link
            else
                @_addHistory()
                # We apply a temporary link metadata in order to make the
                # modification zone visible to the user.
                # We set isUrlPopoverOn so that when we apply this temporary
                # style there is no detection of modification (neither task nor
                # editor content nor anything)
                @isUrlPopoverOn = true
                rg = @_applyMetaDataOnSelection('A','http://')
                if rg
                    segments = @_getLinkSegments(rg)
                    @_showUrlPopover(segments,true)
                else
                    @isUrlPopoverOn = true

        return true


    ###* -----------------------------------------------------------------------
     * initialise the popover during the editor initialization.
    ###
    _initUrlPopover : () ->
        pop  = document.createElement('div')
        pop.id = 'CNE_urlPopover'
        pop.className = 'CNE_urlpop'
        pop.setAttribute.contentEditable = false
        pop.innerHTML =
            """
            <span class="CNE_urlpop_head">Link</span>
            <span  class="CNE_urlpop_shortcuts">(Ctrl+K)</span>
            <div class="CNE_urlpop-content">
                <a target="_blank">Open link <span class="CNE_urlpop_shortcuts">
                    (Ctrl+click)</span></a></br>
                <span>url</span><input type="text"></br>
                <span>Text</span><input type="text"></br>
                <button class="btn">ok</button>
                <button class="btn">Cancel</button>
                <button class="btn">Delete</button>
            </div>
            """
        pop.titleElt = pop.firstChild
        pop.link = pop.getElementsByTagName('A')[0]

        # b = document.querySelector('body')
        # b.insertBefore(frag,b.firstChild)
        [btnOK, btnCancel, btnDelete] = pop.querySelectorAll('button')
        btnOK.addEventListener('click',@_validateUrlPopover)
        btnCancel.addEventListener('click',@_cancelUrlPopoverCB)
        btnDelete.addEventListener 'click', () =>
            pop.urlInput.value = ''
            @_validateUrlPopover()

        [urlInput,textInput] = pop.querySelectorAll('input')
        pop.urlInput = urlInput
        pop.textInput = textInput
        pop.addEventListener 'keypress', (e) =>
            if e.keyCode == 13
                @_validateUrlPopover()
                e.stopPropagation()
            else if e.keyCode == 27
                @_cancelUrlPopover(false)

            return false

        @urlPopover = pop

        return true


    ###* -----------------------------------------------------------------------
     * Show, positionate and initialise the popover for link edition.
     * @param  {array} segments  An array with the segments of
     *                           the link [<a>,...<a>]. Must be created even if
     *                           it is a creation in order to put a background
     *                           on the segment where the link will be.
     * @param  {boolean} isLinkCreation True is it is a creation. In this case,
     *                                  if the process is canceled, the initial
     *                                  state without link will be restored.
    ###
    _showUrlPopover : (segments, isLinkCreation) ->
        pop = @urlPopover

        # Disable the editor to prevent actions when popover is on
        @disable()

        @.isUrlPopoverOn = true
        pop.isLinkCreation = isLinkCreation # save the flag

        # save initial selection range to restore it on close
        pop.initialSelRg = @currentSel.theoricalRange.cloneRange()

        # save segments array
        pop.segments = segments

        # positionnate the popover (centered for now)
        seg = segments[0]
        pop.style.left = seg.offsetLeft + 'px'
        pop.style.top = seg.offsetTop + 20 + 'px'

        # update the inputs fields of popover
        href = seg.href
        if href == '' or href == 'http:///'
            href = 'http://'
        pop.urlInput.value = href
        txt = ''
        txt += seg.textContent for seg in segments
        pop.textInput.value = txt
        pop.initialTxt = txt

        if isLinkCreation
            pop.titleElt.textContent = 'Create Link'
            pop.link.style.display = 'none'
        else
            pop.titleElt.textContent = 'Edit Link'
            pop.link.style.display = 'inline-block'
            pop.link.href = href

        # Insert the popover
        seg.parentElement.parentElement.appendChild(pop)

        # add event listener to detect a click outside of the popover
        @editorBody.addEventListener('mouseup',@_detectClickOutUrlPopover)

        # select and put focus in the popover
        pop.urlInput.select()
        pop.urlInput.focus()

        # colorize the concerned segments.
        for seg in segments
            # seg.style.backgroundColor = '#dddddd'
            seg.classList.add('CNE_url_in_edition')

        return true


    ###* -----------------------------------------------------------------------
     * The callback for a click outside the popover
    ###
    _detectClickOutUrlPopover : (e) =>
        isOut =     e.target != @urlPopover                                    \
                and $(e.target).parents('#CNE_urlPopover').length == 0
        if isOut
            @_cancelUrlPopover(true)


    ###* -----------------------------------------------------------------------
     * Close the popover and revert modifications if isLinkCreation == true
     * @param  {boolean} doNotRestoreOginalSel If true, lets the caret at its
     *                                         position (used when you click
     *                                         outside url popover in order not
     *                                         to loose the new selection)
    ###
    _cancelUrlPopover : (doNotRestoreOginalSel) =>
        pop = @urlPopover
        segments = pop.segments

        # remove the click listener
        @editorBody.removeEventListener('mouseup', @_detectClickOutUrlPopover)

        # remove popover
        pop.parentElement.removeChild(pop)
        @.isUrlPopoverOn = false

        # remove the "selected style" of the segments
        for seg in segments
            # seg.style.removeProperty('background-color')
            seg.classList.remove('CNE_url_in_edition')

        # case of a link creation called and cancelled : a segment for the link
        # to creat has already been added in order to show the selection when
        # popover is visible. As it is canceled, we undo in order to remove this
        # link.
        if pop.isLinkCreation
            s0 = segments[0]
            s1 = segments[segments.length-1]
            bp1 =
                cont   : s0
                offset : 0
            bp2 =
                cont   : s1
                offset : s1.childNodes.length
            bps = [bp1,bp2]
            selection.normalizeBPs(bps)
            lineDiv = selection._getLineDiv(s0)
            @_applyAhrefToSegments(s0, s1 , bps, false, '')
            @_fusionSimilarSegments(lineDiv,bps)
            if !doNotRestoreOginalSel
                @setSelectionBp(bp1, bp2)

        else if !doNotRestoreOginalSel
            sel = this.document.getSelection()
            sel.removeAllRanges()
            sel.addRange(pop.initialSelRg)

        # restore editor enabled
        @setFocus()
        @enable()

        return true


    ###* -----------------------------------------------------------------------
     * Same as _cancelUrlPopover but used in events call backs
    ###
    _cancelUrlPopoverCB : (e) =>
        e.stopPropagation()
        @_cancelUrlPopover(false)


    ###* -----------------------------------------------------------------------
     * Close the popover and applies modifications to the link.
    ###
    _validateUrlPopover : (event) =>

        if event
            event.stopPropagation()

        pop = @urlPopover
        segments = pop.segments

        # 1- in case of a link creation and the user validated an empty url, just
        # cancel the link creation
        if pop.urlInput.value == '' && pop.isLinkCreation
            @_cancelUrlPopover(false)
            return true

        # 2- remove background of selection and hide popover
        # pop.style.display = 'none'
        @editorBody.removeEventListener('mouseup', @_detectClickOutUrlPopover)
        pop.parentElement.removeChild(pop)
        @.isUrlPopoverOn = false
        for seg in segments
            # seg.style.removeProperty('background-color')
            seg.classList.remove('CNE_url_in_edition')

        # 3- in case of a link creation, addhistory has already be done, but it
        # must be done if it is not a link creation.
        if !pop.isLinkCreation
            sel = this.document.getSelection()
            sel.removeAllRanges()
            sel.addRange(pop.initialSelRg) # otherwise addhistory will not work
            @_addHistory()

        # 4- keep a ref to the modified line
        lineDiv  = segments[0].parentElement

        # 5- case of a deletion of the urlInput value => 'remove the link'
        if pop.urlInput.value == ''
            l = segments.length
            bp1 =
                cont : segments[0].firstChild
                offset : 0
            bp2 =
                cont   : segments[l-1].firstChild
                offset : segments[l-1].firstChild.length
            bps = [bp1,bp2]
            @_applyAhrefToSegments(segments[0], segments[l-1], bps, false, '')
            # fusion similar segments if any
            @_fusionSimilarSegments(lineDiv, bps)
            # Position selection
            rg = document.createRange()
            bp1 = bps[0]
            bp2 = bps[1]
            rg.setStart(bp1.cont, bp1.offset)
            rg.setEnd(  bp2.cont, bp2.offset)
            sel = this.document.getSelection()
            sel.removeAllRanges()
            sel.addRange(rg)
            @setFocus()
            # restore editor enabled
            @enable()
            # warn that a change occured
            @editorTarget$.trigger jQuery.Event('onChange')
            # stack Task modifications :
            if lineDiv.dataset.type == 'task'
                @_stackTaskChange(lineDiv.task,'modified')
            return true

        # 6- case if only href is changed but not the text
        else if pop.initialTxt == pop.textInput.value
            seg.href = pop.urlInput.value for seg in segments
            lastSeg = seg

        # 7- case if the text of the link is modified : we concatenate
        # all segments
        else
            seg = segments[0]
            seg.href = pop.urlInput.value
            seg.textContent = pop.textInput.value
            parent = seg.parentNode
            for i in [1..segments.length-1] by 1
                seg = segments[i]
                parent.removeChild(seg)
            lastSeg = segments[0]

        # 8- fusion similar segments if any
        i = selection.getSegmentIndex(lastSeg)
        i = i[1]
        bp = selection.normalizeBP(lineDiv, i+1)
        @_fusionSimilarSegments(lineDiv, [bp])

        # 9- manage selection, find a space after url or add it and move bp
        bp = @insertSpaceAfterUrl(selection.getNestedSegment(bp.cont))
        @_setCaret(bp.cont,bp.offset)
        @setFocus()

        # 10- restore editor enabled
        @enable()

        # 11- warn that a change occured
        @editorTarget$.trigger jQuery.Event('onChange')

        # 12- stack Task modifications :
        if lineDiv.dataset.type == 'task'
            @_stackTaskChange(lineDiv.task,'modified')


    ###* -----------------------------------------------------------------------
     * Tests if a the start break point of the selection or of a range is in a
     * segment being a link. If yes returns the array of the segments
     * corresponding to the link starting in this bp, false otherwise.
     * The link can be composed of several segments, but they are on a single
     * line. Only the start break point is taken into account, not the end bp.
     * Prerequisite : thit.currentSel must havec been updated before calling
     * this function.
     * @param {Range} rg [optionnal] The range to use instead of selection.
     * @return {Boolean} The segment if in a link, false otherwise
    ###
    _getLinkSegments : (rg) ->
        if ! rg
            rg = @currentSel.theoricalRange
        segment1 = selection.getSegment(rg.startContainer,rg.startOffset)
        segments = [segment1]
        if (segment1.nodeName == 'A')
            sibling = segment1.nextSibling
            while sibling != null                \
              &&  sibling.nodeName == 'A'        \
              &&  sibling.href == segment1.href
                segments.push(sibling)
                sibling = sibling.nextSibling
            segments.reverse()
            sibling = segment1.previousSibling
            while sibling != null                \
              &&  sibling.nodeName == 'A'        \
              &&  sibling.href == segment1.href
                segments.push(sibling)
                sibling = sibling.previousSibling
            segments.reverse()
            return segments
        else
            return false


    ###* -----------------------------------------------------------------------
     * Go to end of line and emulate @ pressed
    ###
    emulateAt : () ->

        currentSel = @updateCurrentSelIsStartIsEnd()
        newCont = currentSel.endLine.line$[0].lastChild.previousSibling
        newCont.innerHTML += '@'
        @_keypressCb which: 64
        @_setCaret(newCont,newCont.childNodes.length)
        @_hotString.showAutoAndHighLight()





    ###* -----------------------------------------------------------------------
     * Applies a metadata such as STRONG, UNDERLINED, A/href etc... on the
     * selected text. The selection must not be collapsed.
     * @param  {string} metaData  The css class of the meta data or 'A' if link
     * @param  {string} others... Other params if metadata requires
     *                            some (href for instance)
    ###
    _applyMetaDataOnSelection : (metaData, others...) ->
        currentSel = @updateCurrentSelIsStartIsEnd()
        range = currentSel.theoricalRange
        if range.collapsed
            return

        line = currentSel.startLine
        endLine = currentSel.endLine

        # 1- if the selection starts at the end of a non empty segment, move
        # the start of selection at the beginning of next Segment or even to the
        # start of next line
        if range.startContainer.length != 0 and
           range.startContainer.length == range.startOffset
            seg = selection.getNestedSegment(range.startContainer)
            nextSegment = selection.getNextSegment(seg)
            if nextSegment
                range.setStartBefore(nextSegment.firstChild)
                rangeIsToNormalize = true
            else
                line = line.lineNext
                if line == null
                    return
                range.setStartBefore(line.line$[0].firstChild)
                rangeIsToNormalize = true

        if range.endContainer.length != 0 and
           range.endOffset == 0
            seg = selection.getNestedSegment(range.endContainer)
            prevSegment = selection.getPrevSegment(seg)
            if prevSegment
                range.setEndAfter(prevSegment.lastChild)
                rangeIsToNormalize = true
            else
                endLine = endLine.linePrev
                if endLine == null
                    return
                range.setEndAfter(endLine.line$[0].lastChild)
                rangeIsToNormalize = true
                if range.collapsed
                    return

        if rangeIsToNormalize
            selection.normalize(range)
            if range.collapsed
                return

        # 2- create a range for each selected line and put them in
        # an array (linesRanges)


        # # case when the selection starts at the end of a non empty line
        # if currentSel.firstLineIsEnd
        #     # if start line is empty : apply style to its segment, otherwise
        #     # begin on next line.
        #     if line.line$[0].textContent != ''
        #         line = line.lineNext
        #         if line == null
        #             return
        #         range.setStartBefore(line.line$[0].firstChild)
        #         selection.normalize(range)
        #         if range.collapsed
        #             return

        # # case when the selection ends at the start of the line
        # if currentSel.lastLineIsStart
        #     # if last line is empty : apply style to its segment, otherwise
        #     # begin on the previous line.
        #     if endLine.line$[0].textContent != ''
        #         endLine = endLine.linePrev
        #         if endLine == null
        #             return
        #         range.setEndBefore(endLine.line$[0].lastChild)
        #         selection.normalize(range)
        #         if range.collapsed
        #             return

        # case when metadata is a mono line metadata ('A' for instance), then
        # we limit the selection to the first line
        if metaData == 'A' and line != endLine
            range.setEndBefore(line.line$[0].lastChild)
            selection.normalize(range)
            endLine = line

            # check if range is collapsed, then nothing to do.
            if range.collapsed
                return

        # if a single line selection
        if line == endLine
            linesRanges = [range]

        # if a multi line selection
        else
            # range for the 1st line
            rgStart = range.cloneRange()
            rgStart.setEndBefore(line.line$[0].lastChild)
            selection.normalize(rgStart)
            # linesRanges = @_prepareStartSeg(rgStart)
            linesRanges = [rgStart]
            # ranges for the lines in the middle
            line = line.lineNext
            while line != endLine
                rg = this.document.createRange()
                rg.selectNodeContents(line.line$[0])
                selection.normalize(rg)
                linesRanges.push(rg)
                line = line.lineNext
            # range for the last line
            rgEnd = range.cloneRange()
            rgEnd.setStartBefore(endLine.line$[0].firstChild)
            selection.normalize(rgEnd)
            linesRanges.push(rgEnd)


        # 3- decide if we apply metaData or remove it
        # For this we go throught each line and each selected segment to check
        # if metaData is applied or not. For instance if all segments are strong
        # the action is to un-strongify. If one segment is not bold, then the
        # action is to strongify.
        isAlreadyMeta = true
        for range in linesRanges
            isAlreadyMeta = isAlreadyMeta \
                              &&
                            @_checkIfMetaIsEverywhere(range, metaData, others)
        addMeta = !isAlreadyMeta

        # 4- Apply the correct action on each lines and getback the breakpoints
        # corresponding to the initial range
        bps = []
        for range in linesRanges
            bps.push( @_applyMetaOnLineRange(range, addMeta, metaData, others) )

        # 5- Position selection
        # be carefull : chrome requires the range to be created by the document
        # where the range will be in. In our case, we must use the editor
        # document.
        rg = this.document.createRange()
        bp1 = bps[0][0]
        bp2 = bps[bps.length - 1][1]
        rg.setStart(bp1.cont, bp1.offset)
        rg.setEnd(  bp2.cont, bp2.offset)
        sel = this.currentSel.sel
        sel.removeAllRanges()
        sel.addRange(rg)

        return rg


    ###* -----------------------------------------------------------------------
     * Walk though the segments delimited by the range (which must be in a
     * single line) to check if the meta si on all of them.
     * @param  {range} range a range contained within a line. The range must be
     *                 normalized, ie its breakpoints must be in text nodes.
     * @param  {string} meta  The name of the meta data to look for. It can be
     *                        a css class ('CNE_strong' for instance), or a
     *                        metadata type ('A' for instance)
     * @param  {string} href  Others parameters of the meta data type if
     *                        required (href value for a 'A' meta)
     * @return {boolean}       true if the meta data is already on all the
     *                         segments delimited by the range.
    ###
    _checkIfMetaIsEverywhere : (range, meta, others) ->
        if meta == 'A'
            return @_checkIfAhrefIsEverywhere(range, others[0])
        else
            return @_checkIfCSSIsEverywhere(range,meta,)

    _checkIfCSSIsEverywhere : (range, CssClass) ->
        # Loop  on segments to decide wich action is to be done on all
        #    segments. For instance if all segments are strong the action is
        #    to un-strongify. If one segment is not bold, then the action is
        #    to strongify.
        segment    = range.startContainer.parentNode
        endSegment = range.endContainer.parentNode
        stopNext   = (segment == endSegment)
        loop
            if !segment.classList.contains(CssClass)
                return false
            else
                if stopNext
                    return true
                segment  = segment.nextSibling
                stopNext = (segment == endSegment)

    _checkIfAhrefIsEverywhere : (range, href) ->
        segment    = range.startContainer.parentNode
        endSegment = range.endContainer.parentNode
        stopNext   = (segment == endSegment)
        loop
            if segment.nodeName != 'A' or segment.href != href
                return false
            else
                if stopNext
                    return true
                segment  = segment.nextSibling
                stopNext = (segment == endSegment)


    ###* -----------------------------------------------------------------------
     * Add or remove a meta data to the segments delimited by the range. The
     * range must be within a single line and normalized (its breakpoints must
     * be in text nodes).
     * @param  {range} range    The range on which we want to apply the
     *                          metadata. The range must be within a single line
     *                          and normalized (its breakpoints must be in text
     *                          nodes). The start breakpoint can not be at the
     *                          end of the line, except in the case of an empty
     *                          line fully selected. Same for end breakpoint :
     *                          it can not be at the beginning of the line,
     *                          except in the case of an empty line fully
     *                          selected.
     * @param  {boolean} addMeta  True if the action is to add the metaData,
     *                            False if the action is to remove it.
     * @param  {string} metaData The name of the meta data to look for. It can
     *                           be a css class ('CNE_strong' for instance),
     *                           or a metadata type ('A' for instance)
     * @param {array} others Array of others params fot meta, can be [] but not
     *                       null (not optionnal)
     * @return {array}          [bp1,bp2] : the breakpoints corresponding to the
     *                          initial range after the line transformation.
    ###
    _applyMetaOnLineRange : (range, addMeta, metaData, others) ->
        # 1- var
        lineDiv =  selection.getLineDiv(range.startContainer,range.startOffset)
        startSeg = range.startContainer.parentNode
        endSeg = range.endContainer.parentNode
        bp1 =
            cont   : range.startContainer
            offset : range.startOffset
        bp2 =
            cont   : range.endContainer
            offset : range.endOffset
        breakPoints = [bp1,bp2]

        # 2- create start segment
        #    We split the segment in two of the same type and class if :
        #      - the start segment doesn't have the required property
        #      - the start break point is not strictly inside a node text


        if bp1.offset == 0
            # nothing special, the full segment will be converted, empty or not.

        # case bp1 is at the end of the non empty text node : we start on the
        # next segment. This one must exist, otherwise range would start at the
        # end of a non empty line
        else if bp1.offset == bp1.cont.length
            startSeg = startSeg.nextSibling
            # rem : nextSibling can not be </br> because the start break point
            # can not be at the end of a non empty line. In the latter case the
            # range should have been moved to next line before calling this
            # function.
            if startSeg == null or startSeg.nodeName == 'BR'
                return

        else # ie :  0 < bp1.offset < bp1.cont.length
            isAlreadyMeta = @_isAlreadyMeta(startSeg, metaData, others)
            if       isAlreadyMeta && !addMeta \
                 or !isAlreadyMeta && addMeta
                rg = range.cloneRange()
                # case when bp1 and bp2 are in the same segment
                if endSeg == startSeg
                    # split segment1 in 2 fragments (frag1 & 2)
                    frag1 = rg.extractContents()
                    span = document.createElement(startSeg.nodeName)
                    if startSeg.className != ''
                        span.className = startSeg.className
                    if startSeg.nodeName == 'A'
                        span.href = startSeg.href
                    span = frag1.appendChild(span)
                    span.appendChild(frag1.firstChild)
                    rg.setEndAfter(startSeg)
                    frag2 = rg.extractContents()
                    # insert fragments only in not empty (the notion of "empty"
                    # will probably evolve, for instance with images...)
                    rg.insertNode(frag2) if frag2.textContent != ''
                    rg.insertNode(frag1)
                    # update startSeg, endSeg, bp1 & bp2
                    startSeg = span
                    endSeg = startSeg
                    bp1.cont   = startSeg.firstChild
                    bp1.offset = 0
                    bp2.cont   = endSeg.lastChild
                    bp2.offset = endSeg.lastChild.length
                # case when bp1 and bp2 are in different segments
                else
                    rg.setEndAfter(startSeg)
                    frag1 = rg.extractContents()
                    startSeg = frag1.firstChild
                    bp1.cont   = startSeg.firstChild
                    bp1.offset = 0
                    rg.insertNode(frag1)

        # 3- create end segment
        #    We split the segment in two of the same type and class if :
        #      - the end break point is not strictly inside a node  text
        #      - the end segment doesn't have the required property

        if bp2.offset == bp2.cont.length
            # nothing special, the full segment will be converted, empty or not.

        else if bp2.offset == 0
            endSeg = endSeg.previousSibling
            # rem : previousSibling should not be null because the end break
            # point can not be at the start of a non empty line. In the latter
            # case the range should have been moved to previous line before
            # calling this function.
            if endSeg == null
                return

        else # cas :  0 < bp2.offset < bp2.cont.length
            # isAlreadyMeta = endSeg.classList.contains(metaData)
            isAlreadyMeta = @_isAlreadyMeta(endSeg, metaData, others)
            if  isAlreadyMeta && !addMeta or \
               !isAlreadyMeta && addMeta
                rg = range.cloneRange()
                rg.setStartBefore(endSeg)
                frag1 = rg.extractContents()
                if endSeg == startSeg
                    startSeg = frag1.firstChild
                    bp1.cont   = startSeg.firstChild
                    bp1.offset = 0
                endSeg = frag1.firstChild
                bp2.cont   = endSeg.lastChild
                bp2.offset = endSeg.lastChild.length
                rg.insertNode(frag1)

        # 4- apply the required style
        if metaData == 'A'
            bps = [bp1,bp2]
            @_applyAhrefToSegments(startSeg, endSeg, bps, addMeta, others[0])
        else
            @_applyCssToSegments(startSeg, endSeg, addMeta, metaData)

        # 5- collapse segments with same class
        @_fusionSimilarSegments(lineDiv, breakPoints)

        # 6- stack Task modifications :
        if lineDiv.dataset.type == 'task'
            if !@isUrlPopoverOn
                @_stackTaskChange(lineDiv.task,'modified')

        return [bp1,bp2]


    ###* -----------------------------------------------------------------------
     * Test if a segment already has the meta : same type, same class and other
     * for complex meta (for instance href for <a>)
     * @param  {element}  segment  The segment to test
     * @param  {string}  metaData the type of meta data : A or a CSS class
     * @param  {array}  others   An array of the other parameter of the meta,
     *                           for instance si metaData == 'A',
     *                           others[0] == href
     * @return {Boolean}          True if the segment already have the meta data
    ###
    _isAlreadyMeta : (segment, metaData, others) ->
        if metaData == 'A'
            return segment.nodeName == 'A' && segment.href == others[0]
        else
            return segment.classList.contains(metaData)

    ###* -----------------------------------------------------------------------
     * Applies or remove a meta data of type "A" (link) on a succession of
     * segments (from startSegment to endSegment which must be on the same line)
     * This fuction may let similar segments contiguous, the decision to fusion
     * is to be taken by the caller.
     * @param  {element} startSegment The first segment to modify
     * @param  {element} endSegment   The last segment to modify (must be in the
     *                                same line as startSegment)
     * @param  {Array} bps          [{cont,offset}...] An array of breakpoints
     *                              to update if their container is modified
     *                              while applying the meta data.
     * @param  {Boolean} addMeta      True to apply the meta, False to remove
     * @param  {string} href         the href to use if addMeta is true.
    ###
    _applyAhrefToSegments : (startSegment, endSegment, bps, addMeta, href) ->
        segment  =  startSegment
        stopNext = (segment == endSegment)
        loop
            if addMeta
                if segment.nodeName == 'A'
                    segment.href = href
                else
                    a = document.createElement('A')
                    a.href = href
                    a.textContent = segment.textContent
                    a.className = segment.className
                    for bp in bps
                        if bp.cont.parentNode == segment
                            bp.cont = a.firstChild
                    segment.parentNode.replaceChild(a,segment)
                    segment = a
            else
                    span = document.createElement('SPAN')
                    span.textContent = segment.textContent
                    span.className = segment.className
                    for bp in bps
                        if bp.cont.parentNode == segment
                            bp.cont = span.firstChild
                    segment.parentNode.replaceChild(span,segment)
                    segment = span

            if stopNext
                break
            segment = segment.nextSibling
            stopNext = (segment == endSegment)
        return null


    ###* -----------------------------------------------------------------------
     * Applies or remove a CSS class to a succession of segments (from
     * startsegment to endSegment which must be on the same line)
     * @param  {element} startSegment The first segment to modify
     * @param  {element} endSegment   The last segment to modify (must be in the
     *                                same line as startSegment)
     * @param  {Boolean} addMeta      True to apply the meta, False to remove
     * @param  {String} cssClass     The name of the CSS class to add or remove
    ###
    _applyCssToSegments : (startSegment, endSegment, addMeta, cssClass) ->
        segment  =  startSegment
        stopNext = (segment == endSegment)
        loop
            if addMeta
                segment.classList.add(cssClass)
            else
                segment.classList.remove(cssClass)
            if stopNext
                break
            segment  = segment.nextSibling
            stopNext = (segment == endSegment)
        return null


    ###* -----------------------------------------------------------------------
     * Walk through a line div in order to :
     *   * Concatenate successive similar segments. Similar == same nodeName,
     *     class and if required href.
     *   * Remove empty segments.
     * @param  {element} lineDiv     the DIV containing the line
     * @param  {Array} breakPoints [{cont,offset}...] array of respectively the
     *                              container and offset of the breakpoint to
     *                              update if cont is in a segment modified by
     *                              the fusion.
     *                              /!\ The breakpoint must be normalized, ie
     *                              containers must be in textnodes.
     *                              If the contener of a bp is deleted, then it
     *                              is put before the deleted segment. At the
     *                              bp might be between segments, ie NOT
     *                              normalized since not in a textNode.
     * @return {Array}             A reference to the updated breakpoint.
    ###
    _fusionSimilarSegments : (lineDiv, breakPoints) ->
        segment     = lineDiv.firstChild
        nextSegment = segment.nextSibling
        # case of a line with only one segment : nothing to do
        if nextSegment.nodeName == 'BR'
            return breakPoints

        while nextSegment.nodeName != 'BR'


            if !selection.isSegment(segment)
                segment     = nextSegment
                nextSegment = nextSegment.nextSibling


            # case of an empty segment (for instance after a suppr or backspace)
            # => remove segment
            else if segment.textContent == ''
                segment     = @_removeSegment(segment, breakPoints)
                selection.normalizeBPs(breakPoints)
                nextSegment = segment.nextSibling

            # case of a non empty segment followed by a segment with same meta
            # => fusion segments
            else if @_haveSameMeta(segment, nextSegment)
                @_fusionSegments(segment, nextSegment, breakPoints)
                nextSegment = segment.nextSibling

            # go next
            else
                segment     = nextSegment
                nextSegment = nextSegment.nextSibling

        # check if last segment is empty and is not the only segment
        if     segment.textContent == ''                                       \
           and selection.getSegmentIndex(segment)[0] != 0
            segment = @_removeSegment(segment, breakPoints)
            selection.normalizeBPs(breakPoints)

        return breakPoints

    ###* -----------------------------------------------------------------------
     * Removes a segment and returns a reference to previous sibling or,
     * if doesn't exist, to the next sibling.
     * @param  {element} segment     The segment to remove. Must be in a line.
     * @param  {Array} breakPoints An Array of breakpoint to preserve : if its
     *                             is deleted, the bp is put before the deleted
     *                             segment (it is NOT normalized, since not in a
     *                             textNode)
     * @return {element}       A reference to the previous sibling or,
     *                         if doesn't exist, to the next sibling.
    ###
    _removeSegment : (segment,breakPoints) ->
        # attach the corresponding segment to each bp (must be done each time,
        # because the normalization might have move the bp to a new segment and
        # normalization doesn't update bp.seg )
        if breakPoints.length > 0
            for bp in breakPoints
                bp.seg = selection.getNestedSegment(bp.cont)
        # modify the bp that are in the segment that will be deleted
        for bp in breakPoints
            if bp.seg == segment
                offset = selection.getNodeIndex(segment)
                bp.cont   = segment.parentNode
                bp.offset = offset
        # keep a ref to the previous sibling or, if doesn't exist, next sibling.
        newRef = segment.previousSibling
        if !newRef
            newRef = segment.nextSibling
        # remove segment
        segment.parentNode.removeChild(segment)
        return newRef


    ###* -----------------------------------------------------------------------
     * Imports the content of segment2 in segment1 and updates the breakpoint if
     * this on is  inside segment2
     * @param  {element} segment1    the segment in which the fusion operates
     * @param  {element} segment2    the segement that will be imported in
     *                               segment1
     * @param  {Array} breakPoints [{con,offset}...] array of respectively the
     *                              container and offset of the breakpoint to
     *                              update if cont is in segment2. /!\ The
     *                              breakpoint must be normalized, ie containers
     *                              must be in textnodes.
    ###
    _fusionSegments : (segment1, segment2, breakPoints) ->
        children = Array.prototype.slice.call(segment2.childNodes)
        for child in segment2.childNodes
            segment1.appendChild(child)

        txtNode1 = segment1.firstChild
        txtNode2 = txtNode1.nextSibling
        while txtNode2 != null
            if txtNode1.nodeName == '#text' == txtNode2.nodeName
                for bp in breakPoints
                    if bp.cont == txtNode2
                        bp.cont = txtNode1
                        bp.offset = txtNode1.length + bp.offset
                txtNode1.textContent += txtNode2.textContent
                segment1.removeChild(txtNode2)
                txtNode2 = txtNode1.nextSibling
            else
                txtNode1 = segment1.firstChild
                txtNode2 = txtNode1.nextSibling

        segment2.parentNode.removeChild(segment2)
        return true


    _haveSameMeta : (segment1, segment2) ->
        if segment1.nodeName != segment2.nodeName
            return false
        else if segment1.nodeName == 'A'
            if segment1.href != segment2.href
                return false

        list1 = segment1.classList
        list2 = segment2.classList

        if list1.length != list2.length
            return false

        if list1.length == 0
            return true

        for clas in list2
            if !list1.contains(clas)
                return false
        return true



    ### ------------------------------------------------------------------------
    #  _suppr :
    #
    # Manage deletions when suppr key is pressed
    ###
    _suppr : () ->
        sel = @currentSel
        startLine = sel.startLine
        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed

            # 1.1 caret is at the end of the line
            if sel.rangeIsEndLine

                # if there is a next line : modify the selection to make
                # a multiline deletion
                if startLine.lineNext != null
                    if sel.startLineDiv.nextSibling.dataset.type == 'task'
                        result = window.confirm('Do you want to remove
                            the task from todos ?')

                        if result
                            @_addHistory()
                            @_stackTaskChange(sel.startLineDiv.nextSibling.task,'deleted')
                        else
                            @_addHistory()
                            @_stackTaskChange(sel.startLineDiv.nextSibling.task,'removed')

                        @_turneTaskIntoLine(sel.startLineDiv.nextSibling)

                    sel.range.setEndBefore(
                        startLine.lineNext.line$[0].firstChild)
                    selection.normalize(sel.range)
                    sel.theoricalRange = sel.range.cloneRange()
                    sel.endLine = startLine.lineNext
                    @_deleteMultiLinesSelections()

                # if there is no next line :
                # no modification, just prevent default action
                else
                    # console.info '_suppr 2 - test '

            # 1.2 caret is in the middle of the line : delete one caracter
            else
                # console.info '_suppr 3 - test '
                # we consider that we are in a text node
                textNode = sel.range.startContainer
                startOffset = sel.range.startOffset
                # if carret is at the end of a segment, go to next segment
                if startOffset == textNode.length
                    bp = selection.setBpNextSegEnd(textNode)
                    textNode = bp.cont
                    startOffset = bp.offset
                # delete one caracter in the textNode
                txt = textNode.textContent
                textNode.textContent = txt.substr(0,startOffset) +
                                       txt.substr(startOffset+1)
                bp =
                    cont   : textNode
                    offset : startOffset
                # if new content is empty we remove the corresponding segment
                # (except if it is the last one in the line)
                if textNode.textContent.length == 0
                    @_fusionSimilarSegments(startLine.line$[0], [bp])
                @_setCaret(bp.cont, bp.offset)
                if sel.isStartInTask
                    @_stackTaskChange(sel.startLineDiv.task,'modified')

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            # console.info '_suppr 4 - test '
            # check if there are tags that will be deleted
            @Tags.removeFromRange(sel.theoricalRange)
            # sel can be safely deleted thanks to normalization that have set
            # the selection correctly within the line.
            sel.range.deleteContents()
            bp =
                cont   : sel.range.startContainer
                offset : sel.range.startOffset
            @_fusionSimilarSegments(sel.startLine.line$[0], [bp])
            @_setCaret(bp.cont, bp.offset)
            if sel.isStartInTask
                @_stackTaskChange(sel.startLineDiv.task,'modified')

        # 3- Case of a multi lines selection
        else
            # console.info '_suppr 5 - test '
            @_deleteMultiLinesSelections()

        return false

    ### ------------------------------------------------------------------------
    #  _backspace
    #
    # Manage deletions when backspace key is pressed
    ###
    _backspace : () ->

        sel = @currentSel

        startLine = sel.startLine

        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed
            # 1.1 caret is at the beginning of the line
            if sel.rangeIsStartLine
                # if there is a previous line : modify the selection to make
                # a multiline deletion
                if startLine.linePrev != null
                    if sel.isStartInTask
                        result = window.confirm('Do you want to remove the
                                                 task from todos?')

                        if result
                            @_addHistory()
                            @_stackTaskChange(sel.startLineDiv.task,'deleted')
                        else
                            @_addHistory()
                            @_stackTaskChange(sel.startLineDiv.task,'removed')

                            @_turneTaskIntoLine(sel.startLineDiv)
                            @_setCaret(sel.startLineDiv,0)

                    # console.info '_backspace 3 - test ok'
                    cloneRg = sel.range.cloneRange()
                    cloneRg.setStartBefore(
                        startLine.linePrev.line$[0].lastChild)
                    selection.normalize(cloneRg)
                    sel.theoricalRange = cloneRg
                    sel.startLine = startLine.linePrev
                    @_deleteMultiLinesSelections()

            # 1.2 caret is in the middle of the line : delete one caracter
            else
                # console.info '_backspace 5 - deletion of one caracter'
                # we consider that we are in a text node (selection has been
                # normalized)
                textNode = sel.range.startContainer
                startOffset = sel.range.startOffset
                # if carret is at the begin of a segment, go to previous segment
                if startOffset == 0
                    bp = selection.setBpPreviousSegEnd(textNode)
                    textNode = bp.cont
                    startOffset = bp.offset
                # delete one caracter in the textNode
                txt = textNode.textContent

                textNode.textContent = txt.substr(0,startOffset-1) +
                                       txt.substr(startOffset)
                bp =
                    cont   : textNode
                    offset : startOffset-1
                # if new content is empty we remove the corresponding segment
                # (except if it is the last one in the line)
                if textNode.textContent.length == 0
                    @_fusionSimilarSegments(sel.startLine.line$[0], [bp])
                @_setCaret(bp.cont, bp.offset)
                if sel.isStartInTask
                    @_stackTaskChange(sel.startLineDiv.task,'modified')

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            # console.info '_backspace 6 - test ok'
            # check if there are tags that will be deleted
            @Tags.removeFromRange(sel.theoricalRange)
            # sel can be safely deleted thanks to normalization that have set
            # the selection correctly within the line in text nodes.
            sel.range.deleteContents()

            bp =
                cont   : sel.range.startContainer
                offset : sel.range.startOffset
            @_fusionSimilarSegments(sel.startLine.line$[0], [bp])
            @_setCaret(bp.cont, bp.offset)
            if sel.isStartInTask
                @_stackTaskChange(sel.startLineDiv.task,'modified')

        # 3- Case of a multi lines selection
        else
            @_deleteMultiLinesSelections()

        return true



    ###* -----------------------------------------------------------------------
     * Turn selected lines in a title List (Th). History is incremented.
     * @param  {Line} l [optionnal] The line to convert in Th
    ###
    titleList : (l) ->

        if ! @isEnabled  or @hasNoSelection()
            return true

        @._addHistory()

        # 1- find first and last div of the lines to turn into markers
        if l?
            startDivID = l.lineID
            endLineID  = startDivID
        else
            range = @getEditorSelection().getRangeAt(0)
            startDiv = selection.getLineDiv(
                    range.startContainer,
                    range.startOffset
                )
            endDiv = selection.getLineDiv(
                    range.endContainer,
                    range.endOffset
                )
            startDivID =  startDiv.id
            endLineID = endDiv.id

        # 2- loop on each line between the first and last line selected
        # TODO : deal the case of a multi range (multi selections).
        line = @_lines[startDivID]
        loop
            switch line.lineType
                when 'Tu','To'
                    @_toggleLineType(line)
                when 'Lh'
                    line.setType('Th')
                when 'Lu'
                    line.setType('Tu')
                    @_toggleLineType(line)

            if line.lineID == endLineID
                break
            line = line.lineNext



    ###* -----------------------------------------------------------------------
     * Turn selected lines or the one given in parameter in a
     * Marker List line (Tu)
     * @param  {Line} l [optional] The line to turn in to a Tu
    ###
    markerList : (l) ->

        if ! @isEnabled  or @hasNoSelection()
            return true

        @_addHistory()

        # 1- find first and last div of the lines to turn into markers
        if l?
            startDivID = l.lineID
            endLineID  = startDivID
        else
            range = @getEditorSelection().getRangeAt(0)
            startDiv = selection.getLineDiv(
                    range.startContainer,
                    range.startOffset
                )
            endDiv = selection.getLineDiv(
                    range.endContainer,
                    range.endOffset
                )
            startDivID =  startDiv.id
            endLineID = endDiv.id

        # 2- loop on each line between the first and last line selected
        # TODO : deal the case of a multi range (multi selections).
        line = @_lines[startDivID]
        loop
            switch line.lineType
                when 'Th','To'
                    @_toggleLineType(line)
                when 'Lh', 'Lo'
                    line.setTypeDepth('Tu',line.lineDepthAbs+1)
                when 'Lu'
                    line.setType('Tu')

            if line.lineID == endLineID
                break
            line = line.lineNext


    ### ------------------------------------------------------------------------
    #  _findDepthRel
    #
    # Calculates the relative depth of the line
    #   usage   : cycle : Tu => To => Lx => Th
    #   param   : line : the line we want to find the relative depth
    #   returns : a number
    #
    ###
    _findDepthRel : (line) ->
        if line.lineDepthAbs == 1
            if line.lineType[1] == "h"
                return 0
            else
                return 1
        else
            linePrev = line.linePrev
            while linePrev!=null and linePrev.lineDepthAbs >= line.lineDepthAbs
                linePrev = linePrev.linePrev
            if linePrev != null
                return linePrev.lineDepthRel+1
            else
                return 0


    ###* -----------------------------------------------------------------------
     * Toggle the type of the selected lines.
     * Lx => Tx and Tu <=> Th
     * Increments history.
     * @return {[type]} [description]
    ###
    toggleType : () ->

        if ! @isEnabled  or @hasNoSelection()
            return true

        @._addHistory()

        # 1- Variables
        sel   = @getEditorSelection()
        range = sel.getRangeAt(0)

        startDiv = selection.getLineDiv range.startContainer, range.startOffset
        endDiv = selection.getLineDiv range.endContainer, range.endOffset

        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        endLineID = endDiv.id

        # 3- loop on each line between the first and last line selected
        # TODO : deal the case of a multi range (multi selections).
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        depthIsTreated = {}
        currentDepth = line.lineDepthAbs
        depthIsTreated[currentDepth] = false
        loop
            if ! depthIsTreated[currentDepth]
                done = @_toggleLineType(line)
                depthIsTreated[line.lineDepthAbs] = done
            if line.lineID == endDiv.id
                return
            line = line.lineNext
            if line.lineDepthAbs < currentDepth
                depthIsTreated[currentDepth] = false
                currentDepth = line.lineDepthAbs
            else
                currentDepth = line.lineDepthAbs


    _toggleLineType : (line) ->
        switch line.lineType

            when 'Tu'
                lineTypeTarget = 'Th'
                # transform all its next siblings and lines in Th or Lh
                l = line.lineNext
                while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                    if l.lineDepthAbs == line.lineDepthAbs
                        if l.lineType == 'Tu'
                            l.setType('Th')
                        else if l.lineType == 'Lu'
                            l.setType('Lh')
                        else # when on the same level there are both u and h
                            break # manage only contiguous lines and siblings
                    l = l.lineNext
                # transform all its previous siblings and lines in Th or Lh
                l = line.linePrev
                while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                    if l.lineDepthAbs == line.lineDepthAbs
                        if l.lineType == 'Tu'
                            l.setType('Th')
                        else if l.lineType == 'Lu'
                            l.setType('Lh')
                        else
                            break
                    l = l.linePrev

            when 'Th'
                lineTypeTarget = 'Tu'
                # transform all its next siblings and lines in Tu or Lu
                l = line.lineNext
                while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                    if l.lineDepthAbs == line.lineDepthAbs
                        if l.lineType == 'Th'
                            l.setType('Tu')
                        else if l.lineType == 'Lh'
                            l.setType('Lu')
                        else
                            break
                    l = l.lineNext
                l = line.linePrev
                # transform all its previous siblings and lines in Tu or Lu
                while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                    if l.lineDepthAbs == line.lineDepthAbs
                        if l.lineType == 'Th'
                            l.setType('Tu')
                        else if l.lineType == 'Lh'
                            l.setType('Lu')
                        else
                            break
                    l = l.linePrev

            # when 'Lu'
            #     @markerList(line)

            # when 'Lh'
            #     @titleList( line)

            when 'Lu'
                lineTypeTarget = 'Tu'

            when 'Lh'
                lineTypeTarget = 'Th'

            else
                return false

        line.setType(lineTypeTarget)
        return true



    ###* -----------------------------------------------------------------------
     * Indent selection. History is incremented.
     * @param  {[type]} l [description]
     * @return {[type]}   [description]
    ###
    tab :  (l) ->

        if ! @isEnabled  or @hasNoSelection()
            return true

        @._addHistory()

        # 1- Variables
        if l?
            startDiv = l.line$[0]
            endDiv   = startDiv
        else
            sel   = @getEditorSelection()
            range = sel.getRangeAt(0)

            startDiv = selection.getLineDiv(
                    range.startContainer,
                    range.startOffset
                )
            endDiv = selection.getLineDiv(
                    range.endContainer,
                    range.endOffset
                )

        endLineID = endDiv.id

        # 2- loop on each line between the first and last line selected
        # TODO : deal the case of a multi range (multi selections).
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        loop
            @_tabLine(line)
            if line.lineID == endLineID
                break
            else
                line = line.lineNext


    _tabLine : (line) ->
        switch line.lineType
            when 'Tu','Th','To'
                # find previous sibling to check if a tab is possible
                # (no tab if no previous sibling)
                prevSibling = @_findPrevSiblingT(line)
                if prevSibling == null
                    return
                # determine new lineType
                if prevSibling.lineType == 'Th'
                    typeTarget = 'Lh'
                else if prevSibling.lineType == 'Tu'
                    typeTarget = 'Lu'
                else
                    typeTarget = 'Lo'

            when 'Lh', 'Lu', 'Lo'
                depthAbsTarget = line.lineDepthAbs + 1

                # find next sibling
                nextSib = @_findNextSibling(line, depthAbsTarget)
                nextSibType = if nextSib == null then null else nextSib.lineType

                # find previous sibling
                prevSib = @_findPrevSiblingT(line, depthAbsTarget)
                prevSibType = if prevSib == null then null else prevSib.lineType

                typeTarget = @_chooseTypeTarget(prevSibType,nextSibType)

                if typeTarget == 'Th'
                    line.lineDepthAbs += 1
                    line.lineDepthRel  = 0
                else
                    line.lineDepthAbs += 1
                    line.lineDepthRel += 1

        line.setType(typeTarget)
        @adjustSiblingsToType(line)


    _chooseTypeTarget : (prevSibType,nextSibType) ->
        # If there are no siblings => Tu
        if  prevSibType == nextSibType == null
            typeTarget = 'Tu'
        # If There are 2 identical, => use their type
        else if prevSibType == nextSibType
            typeTarget = nextSibType
        # If only one sibling, use its type
        else if prevSibType == null
            typeTarget = nextSibType
        # If only one sibling, use its type
        else if nextSibType == null
            typeTarget = prevSibType
        # If the two siblings have differents types => Tu
        else
            typeTarget = 'Tu'
        return typeTarget



    ###* -----------------------------------------------------------------------
     * Un-indent the selection. History is incremented.
     * @param  {Range} range [optional] A range containing the lines to un-indent
    ###
    shiftTab : (range) ->

        if ! @isEnabled or @hasNoSelection()
            return true

        @._addHistory()

        # 1- Variables
        unless range?
            sel   = @getEditorSelection()
            range = sel.getRangeAt(0)

        startDiv = selection.getLineDiv range.startContainer, range.startOffset
        endDiv = selection.getLineDiv range.endContainer, range.endOffset

        endLineID = endDiv.id

        # 2- loop on each line between the first and last line selected
        line = @_lines[startDiv.id]
        loop
            @_shiftTabLine(line)
            if line.lineID == endDiv.id
                break
            else
                line = line.lineNext

        return true



    ###* -----------------------------------------------------------------------
     * un-tab a single line
     * @param  {line} line the line to un-tab
    ###
    _shiftTabLine : (line) ->
        switch line.lineType
            when 'Tu','Th','To'
                # find the closest parent to choose the new lineType.
                parnt = line.linePrev
                while parnt != null and parnt.lineDepthAbs >= line.lineDepthAbs
                    parnt = parnt.linePrev
                if parnt == null
                    return

                # if lineNext is a Lx of line, then it must be turned in a Tx
                if line.lineNext? and
                  line.lineNext.lineType[0] == 'L' and
                  line.lineNext.lineDepthAbs == line.lineDepthAbs
                    nextL = line.lineNext
                    nextL.setType('T'+nextL.lineType[1])
                # if the line under is already deaper, all sons must have
                # their depth reduced
                nextL = line.lineNext
                if nextL and nextL.lineDepthAbs > line.lineDepthAbs
                    while nextL && nextL.lineDepthAbs > line.lineDepthAbs
                        nextL.setDepthAbs(nextL.lineDepthAbs - 1)
                        nextL = nextL.lineNext
                    if nextL? and nextL.lineType[0]=='L'
                        nextL.setType('T'+nextL.lineType[1])
                typeTarget = parnt.lineType
                typeTarget = "L" + typeTarget.charAt(1)
                line.lineDepthAbs -= 1
                line.lineDepthRel -= parnt.lineDepthRel

            when 'Lh', 'Lu', 'Lo'
                depthAbsTarget = line.lineDepthAbs

                # find next sibling
                nextSib = @_findNextSibling(line, depthAbsTarget)
                nextSibType = if nextSib == null then null else nextSib.lineType

                # find previous sibling
                prevSib = @_findPrevSiblingT(line, depthAbsTarget)
                prevSibType = if prevSib == null then null else prevSib.lineType

                typeTarget = @_chooseTypeTarget(prevSibType,nextSibType)


        line.setType(typeTarget)
        @adjustSiblingsToType(line)

    adjustSiblingsToType: (line) ->
        lineIt = line
        loop
            if lineIt.lineDepthAbs == line.lineDepthAbs
                if lineIt.lineType[1] != line.lineType[1]
                    lineIt.setType(lineIt.lineType[0] + line.lineType[1])
            lineIt = lineIt.lineNext
            if  lineIt == null or lineIt.lineDepthAbs < line.lineDepthAbs
                break



    ###* -----------------------------------------------------------------------
     * Return on the carret position. Selection must be normalized but not
     * necessarily collapsed.
    ###
    _return : () ->
        currSel   = this.currentSel
        startLine = currSel.startLine
        endLine   = currSel.endLine

        # 0- check if the start break point is in a task
        rg = currSel.range
        isInTask = currSel.isStartInTask


        # 1- Delete the selections so that the selection is collapsed
        if currSel.range.collapsed

        else if endLine == startLine
            rg.deleteContents()
            bp1 = selection.normalizeBP(rg.startContainer, rg.startOffset)
            @_fusionSimilarSegments(startLine.line$[0],[bp1])
            rg.setStart(bp1.cont,bp1.offset)
            rg.collapse(true)

        else
            @_deleteMultiLinesSelections()
            currSel   = @updateCurrentSelIsStartIsEnd()
            startLine = currSel.startLine

        # 2- Caret is at the end of the line
        if currSel.rangeIsEndLine
            newLine = @_insertLineAfter (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
            )
            # Position caret
            @_setCaret(newLine.line$[0].firstChild.firstChild,0)
            if isInTask
                @_turneLineIntoTask(newLine.line$[0])

        # 3- Caret is at the beginning of the line
        else if currSel.rangeIsStartLine
            # console.info '  F1 - currSel.rangeIsStartLine'
            newLine = @_insertLineBefore (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
            )
            # Position caret
            if isInTask
                @_turneLineIntoTask(newLine.line$[0])
            else
                @_setCaret(startLine.line$[0].firstChild.firstChild,0)

        # 4- Caret is in the middle of the line
        else
            # Deletion of the end of the original line
            currSel.range.setEndBefore( startLine.line$[0].lastChild )
            # If the line is a task :
            if currSel.isStartInTask
                @_stackTaskChange(startLine.line$[0].task,'modified')
            # testFrag = currSel.range.cloneContents()
            endOfLineFragment = currSel.range.extractContents()
            # insertion
            newLine = @_insertLineAfter (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
                fragment           : endOfLineFragment
            )
            @_fusionSimilarSegments(newLine.line$[0], [])
            # Position caret
            @_setCaret(newLine.line$[0].firstChild.firstChild,0)
            if isInTask
                @_turneLineIntoTask(newLine.line$[0])

        # adjuste scroll if the new line gets out of the editor
        l = newLine.line$[0]
        p = l.parentNode
        dh = p.getBoundingClientRect().height
        if  !( (l.offsetTop + 20 - dh) < p.scrollTop < l.offsetTop )
            l.scrollIntoView(false)

    ###* -----------------------------------------------------------------------
     * Returns the first line of the editor.
     * @return {Line} First line of the editor.
    ###
    getFirstline : () ->
        return @_lines[ @linesDiv.childNodes[0].id ]

    _getSelectedLineDiv : () ->
        cont = this.document.getSelection().getRangeAt(0).startContainer
        return selection.getLineDiv(cont)

    ### ------------------------------------------------------------------------
    #  _findParent1stSibling
    #
    # find the sibling line of the parent of line that is the first of the list
    # ex :
    #   . Sibling1 <= _findParent1stSibling(line)
    #   . Sibling2
    #   . Parent
    #      . child1
    #      . line     : the line in argument
    # returns null if no previous sibling, the line otherwise
    # the sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
    ###
    _findParent1stSibling : (line) ->
        lineDepthAbs = line.lineDepthAbs
        linePrev = line.linePrev
        if linePrev == null
            return line
        if lineDepthAbs <= 2
            # in the 2 first levels the answer is _firstLine
            while linePrev.linePrev != null
                linePrev = linePrev.linePrev
            return linePrev
        else
            while linePrev != null and linePrev.lineDepthAbs > (lineDepthAbs-2)
                linePrev = linePrev.linePrev
            return linePrev.lineNext

    ###* -----------------------------------------------------------------------
     * Find the next sibling line.
     * Returns null if no next sibling, the line otherwise.
     * The sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
     * @param  {line} line     The starting line for which we search a sibling
     * @param  {number} depthAbs [optional] If the siblings we search is not
     *                           of the same absolute depth
     * @return {line}          The next sibling if one, null otherwise
    ###
    _findNextSibling : (line, depth)->
        if !depth?
            depth = line.lineDepthAbs

        nextSib = line.lineNext
        loop
            if nextSib == null or nextSib.lineDepthAbs < depth
                nextSib = null
                break
            else if nextSib.lineDepthAbs == depth && nextSib.lineType[0] == 'T'
                break
            nextSib = nextSib.lineNext
        return nextSib



    ###* -----------------------------------------------------------------------
     * Find the previous sibling line being a Title.
     * Returns null if no previous sibling, the line otherwise.
     * The sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
     * @param  {line} line     Rhe starting line for which we search a sibling
     * @param  {number} depthAbs [optional] If the siblings we search is not
     *                           of the same absolute depth
     * @return {line}          The previous sibling if one, null otherwise
    ###
    _findPrevSiblingT : (line, depth)->
        if !depth
            depth = line.lineDepthAbs

        prevSib = line.linePrev
        loop
            if prevSib == null or prevSib.lineDepthAbs < depth
                prevSib = null
                break
            else if prevSib.lineDepthAbs == depth && prevSib.lineType[0] == 'T'
                break
            prevSib = prevSib.linePrev

        return prevSib



    ###* -----------------------------------------------------------------------
     * Find the previous sibling line (can be a line 'Lx' or a title 'Tx').
     * Returns null if no previous sibling, the line otherwise.
     * @param  {line} line     The starting line for which we search a sibling
     * @param  {number} depthAbs [optional] If the siblings we search is not
     *                           of the same absolute depth
     * @return {line}          The previous sibling if one, null otherwise
    ###
    _findPrevSibling : (line, depth)->
        if !depth
            depth = line.lineDepthAbs

        prevSib = line.linePrev
        loop
            if prevSib == null or prevSib.lineDepthAbs < depth
                prevSib = null
                break
            else if prevSib.lineDepthAbs == depth
                break
            prevSib = prevSib.linePrev

        return prevSib


    ###* -----------------------------------------------------------------------
     * Delete the user multi line selection :
     *   * The 2 lines (selected or given in param) must be distinct
     *   * If no params :
     *       - @currentSel.theoricalRange will the range used to find the
     *         lines to delete.
     *       - Only the range is deleted, not the beginning of startline nor the
     *         end of endLine
     *       - the caret is positionned at the firts break point of range.
     *   * if startLine and endLine is given
     *      - the whole lines from start and endLine are deleted, both included.
     *      - the caret position is not updated by this function.
     * @param  {[line]} startLine [optional] if exists, the whole line will be
     *                                       deleted
     * @param  {[line]} endLine   [optional] if exists, the whole line will be
     *                                       deleted
     * @return {[none]}           [nothing]
    ###
    _deleteMultiLinesSelections : (startLine, endLine) ->

        # TODO  BJA : to remove when _moveLinesDown and _moveLinesUp will be
        # debugged
        if startLine == null or endLine == null
            throw new Error(
                'CEeditor._deleteMultiLinesSelections called with a null param'
                )

        # Get start and end positions of the selection.
        if startLine?
            range = this.document.createRange()
            selection.cleanSelection(startLine, endLine, range)
            replaceCaret = false
        else
            # currentSel has been updated by _keyDownCb
            # We don't use @currentSel.range because with chrome it might
            # not be in a text node...
            range          = @currentSel.theoricalRange
            startContainer = range.startContainer
            startOffset    = range.startOffset
            startLine      = @currentSel.startLine
            endLine        = @currentSel.endLine
            replaceCaret = true

        # check if there are tags that will be deleted
        @Tags.removeFromRange(range)

        # Calculate depth for start and end line
        endLineDepth   = endLine.lineDepthAbs

        # Copy the un-selected end of endLine in a fragment
        endOfLineFragment = selection.cloneEndFragment(range, endLine)

        # Adapt end line type if needed.
        # @_adaptEndLineType startLine, endLine, endLineDepth

        # Detect the task that will be removed
        if startLine.line$[0].dataset.type == 'task'
            @_stackTaskChange(startLine.line$[0].task,'modified')
        line = startLine.lineNext
        while line != endLine
            if line.line$[0].dataset.type == 'task'
                @_stackTaskChange(line.line$[0].task,'removed')
            line = line.lineNext
        if line.line$[0].dataset.type == 'task'
            @_stackTaskChange(line.line$[0].task,'removed')

        # Delete selection and adapt remaining parts consequently.
        range.deleteContents()

        # Insert the copied end of line at the end of startLine
        @_addMissingFragment(startLine, endOfLineFragment)

        # Remove endLine from this.lines and updates links
        @_removeEndLine(startLine, endLine)

        # Adapt depth & type

        # Calculate depth for start and end line
        startLineDepth = startLine.lineDepthAbs
        # endLineDepth   = endLine.lineDepthAbs
        # deltaDepth     = endLineDepth - startLineDepth

        # adjust depth of the sons and siblings of endLine if deltadpeth > 1
        firstNextLine = startLine.lineNext
        if firstNextLine
            firstNextLineDepth = firstNextLine.lineDepthAbs
            currentDelta = firstNextLine.lineDepthAbs - startLineDepth
            deltaInserted  = endLineDepth - startLineDepth

            @_adaptDepth(startLine,deltaInserted, currentDelta, startLineDepth)
            # @_adaptDepth(startLine, endLineDepth)
            @_adaptType(startLine)

        # Fusion similar segments and place caret if required
        if replaceCaret
            bp =
                cont   : startContainer
                offset : startOffset
            @_fusionSimilarSegments(startLine.line$[0], [bp])
            @_setCaret(bp.cont, bp.offset)
        else
            @_fusionSimilarSegments(startLine.line$[0], [])


    #  Adapt the depth of the children and following siblings of end line
    #    in case the depth delta between start and end line is
    #    greater than 0, then the structure is not correct : we reduce
    #    the depth of all the children and siblings of endLine.
    #
    #  Then adapt the type of the first line after the children and siblings of
    #    end line. Its previous sibling or parent might have been deleted,
    #    we then must find its new one in order to adapt its type.
    ###* -----------------------------------------------------------------------
     * After an insertion or deletion of a bloc of lines, the lines following
     * the bloc might be incoherent (depth and type of the lines)
     * This function goes throught these lines to correct their depth.
     * @param  {Line} startLine     The first line after the bloc of inserted or
     *                              deleted lines
     * @param  {Number} deltaInserted Delta of depth between the first line of
     *                                the block and its last one.
     * @param  {number} currentDelta  Delta of depth between the last line of
     *                                the block (startLine) and the following.
     * @param  {Number} minDepth      The depth under wich (this one included)
     *                                we are sure the structure is valid and
     *                                there is no need to check.
    ###
    _adaptDepth: (startLine, deltaInserted, currentDelta, minDepth) ->
        if startLine.lineNext == null
            return


        # adjust depth of the sons and siblings of endLine if deltadpeth > 1
        firstNextLine = startLine.lineNext
        if currentDelta > 1
            lineIt = firstNextLine
            lineIt = @_unIndentBlock(lineIt,deltaInserted)
            while lineIt != null && lineIt.lineDepthAbs > minDepth
                lineIt = @_unIndentBlock(lineIt,deltaInserted)

        return true

    _adaptType: (startLine) ->
        # depth are ok, now check type : for each line after firstNextLine find
        # its previous sibling and compare type
        lineIt = startLine.lineNext
        while lineIt != null
            prev = @_findPrevSibling(lineIt)
            if prev == null
                if lineIt.lineType[0] != 'T'
                    lineIt.setType('T'+lineIt.lineType[1])
            else if prev.lineType[1] != lineIt.lineType[1]
                # ex : Lu and Th : Th => Tu
                lineIt.setType(lineIt.lineType[0]+prev.lineType[1])
            lineIt = lineIt.lineNext

        return true



    _unIndentBlock: (firstLine,delta) ->
        line = firstLine
        firstLineDepth = firstLine.lineDepthAbs
        newDepth = Math.max(1,line.lineDepthAbs - delta)
        delta = line.lineDepthAbs - newDepth
        while line!= null and line.lineDepthAbs >= firstLineDepth
            newDepth = line.lineDepthAbs - delta
            line.setDepthAbs(newDepth)
            line = line.lineNext
        return line



            # if line != null and line != firstLineAfterSiblingsOfDeleted
            #     prevSiblingType = line.lineType
            #     if firstLineAfterSiblingsOfDeleted.lineType != prevSiblingType
            #         if prevSiblingType[1] == 'h'
            #             @titleList(firstLineAfterSiblingsOfDeleted)
            #         else
            #             @markerList(firstLineAfterSiblingsOfDeleted)


    # Add back missing unselected fragment that have been deleted by our rough
    # deletion.
    # If startFrag et myEndLine are SPAN and they both have the same class
    # then we concatenate both
    _addMissingFragment: (line, fragment) ->
        startFrag = fragment.childNodes[0]
        lineEl = line.line$[0]

        if lineEl.lastChild is null
            node = document.createElement('span')
            lineEl.insertBefore(node,lineEl.firstChild)

        if lineEl.lastChild.nodeName is 'BR'
            lineEl.removeChild(lineEl.lastChild)
        lastNode = lineEl.lastChild

        if startFrag.tagName == lastNode.tagName == 'SPAN' and
           startFrag.className == lastNode.className
            startOffset = lastNode.textContent.length
            newText = lastNode.textContent + startFrag.textContent
            lastNode.firstChild.textContent = newText
            fragment.removeChild(fragment.firstChild)
            lineEl.appendChild fragment
        else
            lineEl.appendChild fragment
            null


    # Remove end line and update line links of the start line.
    _removeEndLine : (startLine, endLine) ->
        startLine.lineNext = endLine.lineNext
        endLine.lineNext.linePrev = startLine if endLine.lineNext != null
        endLine.line$.remove()
        delete @_lines[endLine.lineID]


    # adapt the type of endLine and of its children to startLine
    # the only useful case is when endLine must be changed from Th to Tu or To
    _adaptEndLineType : (startLine, endLine, endLineDepthAbs) ->
        endType    = endLine.lineType
        startType  = startLine.lineType
        deltaDepth = endLineDepthAbs - startLine.lineDepthAbs
        # Tu => Tu : nothing
        # Tu => Th : Toggle
        if endType == 'Tu' && startType == 'Th'
            @_toggleLineType(endLine)
            line = endLine
            if deltaDepth > 0
                while line!= null and line.lineDepthAbs >= endLineDepthAbs
                    newDepth = line.lineDepthAbs - deltaDepth
                    line.setDepthAbs(newDepth)
                    line = line.lineNext
        # Tu => Lu : nothing ok

        # TU => Lh : nothing ok

        # Th => Tu : Toggle
        else if endType == 'Th' && startType == 'Tu'
            @_toggleLineType(endLine)
            line = endLine
            if deltaDepth > 0
                while line!= null and line.lineDepthAbs >= endLineDepthAbs
                    newDepth = line.lineDepthAbs - deltaDepth
                    line.setDepthAbs(newDepth)
                    line = line.lineNext

        # Th => Th : juste adapt depth of endline's siblings
        else if endType == 'Th' && startType == 'Th'
            line = endLine
            if deltaDepth > 0
                while line!= null and line.lineDepthAbs >= endLineDepthAbs
                    newDepth = line.lineDepthAbs - deltaDepth
                    line.setDepthAbs(newDepth)
                    line = line.lineNext

        # Th => Lu : nothing ok
        # Th => Lh : nothing ok
        #
        # Lh => Tu : nothing ok
        # Lh => Th : nothing ok
        # Lh => Lu : nothing ok
        # Lh => Lh : nothing ok

        # Lu => Tu : Toggle
        # Lu => Th : nothing
        # Lu => Lu : Toggle
        # Lu => Lh : nothing

        # if endType[1] is 'h' and startType[1] isnt 'h'
        #     if endType[0] is 'L'
        #         endLine.setType('T' + endType[1])
        #     @markerList endLine


    ###* -----------------------------------------------------------------------
     * Put caret at given position. The break point will be normalized (ie put
     * in the closest text node).
     * @param {element} startContainer Container of the break point
     * @param {number} startOffset    Offset of the break point
     * @param  {boolean} preferNext [optional] if true, in case BP8, we will
     *                              choose to go in next sibling - if exists -
     *                              rather than in the previous one.
     * @return {Object} {cont,offset} the normalized break point
    ###
    _setCaret : (startContainer, startOffset, preferNext) ->
        bp = selection.normalizeBP(startContainer, startOffset, preferNext)
        range = this.document.createRange()
        range.setStart(bp.cont, bp.offset)
        range.collapse(true)
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        return bp

    _setCaretAfter : (elemt) ->
        nextEl = elemt
        while nextEl.nextSibling == null
            nextEl = nextEl.parentElement
        nextEl = nextEl.nextSibling
        if nextEl.nodeName == 'BR'
            index = 0
            parent = elemt.parentNode
            while parent.childNodes[index] != elemt
                index += 1
            @_setCaret(parent,index + 1)
        else
            @_setCaret(nextEl,0)

    _setSelectionOnNode : (node) ->
        range = this.document.createRange()
        range.selectNodeContents(node)
        selection.normalize(range)
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        return true

    setSelection : (startContainer,startOffset,endContainer,endOffset) ->
        range = this.document.createRange()
        range.setStart(startContainer, startOffset )
        range.setEnd(endContainer, endOffset)
        selection.normalize(range)
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        return true

    setSelectionFromRg : (range, preferNext) ->
        selection.normalize(range, preferNext)
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        return true



    setSelectionBp : (bp1,bp2) ->
        range = this.document.createRange()
        range.setStart(bp1.cont, bp1.offset )
        range.setEnd(bp2.cont, bp2.offset)
        selection.normalize(range)
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        return true



    ### ------------------------------------------------------------------------
    #  _insertLineAfter
    #
    # Insert a line after a source line
    # The line will be inserted in the parent of the source line (which can be
    # the editor or a fragment in the case of the paste for instance)
    # p =
    #     sourceLine         : line after which the line will be added
    #     fragment           : [optionnal] - an html fragment that will be added
    #                          in the div of the line.
    #     innerHTML          : [optionnal] - if no fragment is given, an html
    #                          string that will be added to the new line.
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineAfter : (p) ->
        newLine    = new Line(
                @                    , # editor
                p.targetLineType     , # type
                p.targetLineDepthAbs , # depth abs
                p.targetLineDepthRel , # depth relative
                p.sourceLine         , # previous line
                null                 , # next line
                p.fragment             # fragment
            )
        return newLine



    ### ------------------------------------------------------------------------
    #  _insertLineBefore
    #
    # Insert a line before a source line
    # p =
    #     sourceLine         : Line before which a line will be added
    #     fragment           : [optionnal] - an html fragment that will be added
    #                          the fragment is not supposed to end with a <br>
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineBefore : (p) ->
        newLine    = new Line(
                @                    , # editor
                p.targetLineType     , # type
                p.targetLineDepthAbs , # depth abs
                p.targetLineDepthRel , # depth relative
                null                 , # previous line
                p.sourceLine         , # next line
                p.fragment             # fragment
            )
        return newLine



    ###* -----------------------------------------------------------------------
     * Parse a raw html inserted in the iframe in order to update the controller
    ###
    _readHtml: () ->
        linesDiv$    = $(@linesDiv).children()  # linesDiv$= $[Div of lines]
        # loop on lines (div) to initialise the editor controler
        lineDepthAbs = 0
        lineDepthRel = 0
        lineID       = 0
        @_lines      = {}
        linePrev     = null
        lineNext     = null

        for htmlLine in linesDiv$
            htmlLine$ = $(htmlLine)
            lineClass = htmlLine$.attr('class') ? ""
            lineClass = lineClass.split('-')
            lineType  = lineClass[0]
            if lineType != ""
                lineDepthAbs_old = lineDepthAbs
                # hypothesis : _readHtml is called only on an html where
                #              class="Tu-xx" where xx is the absolute depth
                lineDepthAbs     = +lineClass[1]
                deltaDepthAbs    = lineDepthAbs - lineDepthAbs_old
                lineDepthRel_old = lineDepthRel
                if lineType == "Th"
                    lineDepthRel = 0
                else
                    lineDepthRel = lineDepthRel_old + deltaDepthAbs
                lineID=(parseInt(lineID,10)+1)
                lineID_st = "CNID_"+lineID
                htmlLine$.prop("id",lineID_st)
                lineNew = new Line()
                lineNew.line$        = htmlLine$
                lineNew.lineID       = lineID_st
                lineNew.lineType     = lineType
                lineNew.lineDepthAbs = lineDepthAbs
                lineNew.lineDepthRel = lineDepthRel
                lineNew.lineNext     = null
                lineNew.linePrev     = linePrev
                if linePrev != null then linePrev.lineNext = lineNew
                linePrev = lineNew
                @_lines[lineID_st] = lineNew
                # if some lines are empty, add the text node
                if htmlLine.textContent == ''
                    if htmlLine.firstChild.childNodes.length == 0
                        txt = document.createTextNode('')
                        htmlLine.firstChild.appendChild(txt)

            # If line is a task, init the task
            if htmlLine.dataset.type == 'task'
                if @isChromeOrSafari
                    htmlLine.firstChild.textContent = ' '
                else
                    htmlLine.firstChild.textContent = '\u00a0'
                @_setTaskToLine(htmlLine)

            # loop on spans of the line to check the tags
            seg = htmlLine.firstChild
            while seg.nodeName == 'SPAN'
                if seg.dataset.type
                    @Tags._tagList.push(seg) # not clean, but perf...
                seg = seg.nextSibling

        @_highestId = lineID



    ### ------------------------------------------------------------------------
    # LINES MOTION MANAGEMENT
    #
    # Functions to perform the motion of an entire block of lines
    # BUG : when doubleclicking on an end of line then moving this line
    #       down, selection does not behave as expected :-)
    # TODO: correct behavior when moving the second line up
    # TODO: correct behavior when moving the first line down
    # TODO: improve re-insertion of the line swapped with the block
    ####


    ### ------------------------------------------------------------------------
    # _moveLinesDown:
    #
    # -variables:
    #    linePrev                                       linePrev
    #    lineStart__________                            lineNext
    #    |.                 | The block                 lineStart_______
    #    |.                 | to move down      ==>     |.              |
    #    lineEnd____________|                           |.              |
    #    lineNext                                       lineEnd_________|
    #
    # -algorithm:
    #    1.delete lineNext with _deleteMultilinesSelections()
    #    2.insert lineNext between linePrev and lineStart
    #    3.if lineNext is more indented than linePrev, untab lineNext
    #      until it is ok
    #    4.else (lineNext less indented than linePrev), select the block
    #      (lineStart and some lines below) that is more indented than lineNext
    #      and untab it until it is ok
    ###
    _moveLinesDown : () ->

        # 0 - Set variables with informations on the selected lines
        sel   = @getEditorSelection()
        range = sel.getRangeAt(0)

        # TODO BJA : use findlines ?
        startDiv = selection.getLineDiv range.startContainer, range.startOffset
        endDiv = selection.getLineDiv range.endContainer, range.endOffset

        # Find first and last div corresponding to the first and last
        # selected lines
        startLineID = startDiv.id
        endLineID = endDiv.id

        lineStart = @_lines[startLineID]
        lineEnd   = @_lines[endLineID]
        linePrev  = lineStart.linePrev
        lineNext  = lineEnd.lineNext

        # if the last selected line (lineEnd) isnt the very last line
        if lineNext != null

            # 1 - save lineNext
            cloneLine = Line.clone(lineNext)

            # 2 - Delete lineNext content then restore initial selection
            # TODO BJA : ensure this call don't pass a null param
            @_deleteMultiLinesSelections(lineEnd, lineNext)

            # rangy.restoreSelection(savedSel)

            # 3 - Restore lineNext before the first selected line (lineStart)
            lineNext = cloneLine
            @_lines[lineNext.lineID] = lineNext

            # 4 - Modify the order of linking :
            #        linePrev--lineNext--lineStart--lineEnd
            lineNext.linePrev  = linePrev
            lineStart.linePrev = lineNext
            if lineNext.lineNext != null
                lineNext.lineNext.linePrev = lineEnd
            lineEnd.lineNext  = lineNext.lineNext
            lineNext.lineNext = lineStart
            if linePrev != null
                linePrev.lineNext = lineNext

            # 5 - Replace the lineNext line in the DOM
            lineStart.line$.before(lineNext.line$)

            # 6 - Re-insert lineNext after the end of the moved block.
            #     2 different configs of indentation may occur :

            if linePrev == null then return

            # 6.1 - The swapped line (lineNext) is less indented than
            #       the block's prev line (linePrev)
            if lineNext.lineDepthAbs <= linePrev.lineDepthAbs
                # find the last line to untab
                line = lineNext
                while (line.lineNext!=null and
                       line.lineNext.lineDepthAbs > lineNext.lineDepthAbs)
                    line = line.lineNext
                if line.lineNext != null
                    line = line.lineNext
                # select a block from first line to untab (lineStart)
                #                  to last  line to untab (line)
                myRange = this.document.createRange()
                myRange.setStart(lineStart.line$[0], 0)
                myRange.setEnd(line.line$[0], 0)
                # untab this selected block.
                numOfUntab = lineStart.lineDepthAbs-lineNext.lineDepthAbs
                if lineNext.lineNext.lineType[0]=='T'
                    # if linePrev is a 'T' and a 'T' follows, one untab less
                    if lineStart.lineType[0] == 'T'
                        numOfUntab -= 1
                    # if linePrev is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1

                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1

            # 6.2 - The swapped line (lineNext) is more indented than
            #       the block's prev line (linePrev)
            else
                # untab lineNext
                myRange = this.document.createRange()
                myRange.setStart(lineNext.line$[0], 0)
                myRange.setEnd(lineNext.line$[0], 0)
                numOfUntab = lineNext.lineDepthAbs - linePrev.lineDepthAbs

                if lineStart.lineType[0]=='T'
                    # if lineEnd is a 'T' and a 'T' follows, one untab less
                    if linePrev.lineType[0]=='T'
                        numOfUntab -= 1
                    # if lineEnd is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1

                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1


    ### ------------------------------------------------------------------------
    # _moveLinesUp:
    #
    # -variables:
    #    linePrev                                   lineStart_________
    #    lineStart__________                        |.                |
    #    |.                 | The block             |.                |
    #    |.                 | to move up     ==>    lineEnd___________|
    #    lineEnd____________|                       linePrev
    #    lineNext                                   lineNext
    #
    # -algorithm:
    #    1.delete linePrev with _deleteMultilinesSelections()
    #    2.insert linePrev between lineEnd and lineNext
    #    3.if linePrev is more indented than lineNext, untab linePrev
    #      until it is ok
    #    4.else (linePrev less indented than lineNext), select the block
    #      (lineNext and some lines below) that is more indented than linePrev
    #      and untab it until it is ok
    ###
    _moveLinesUp : () ->

        # 0 - Set variables with informations on the selected lines
        sel   = @getEditorSelection()
        range = sel.getRangeAt(0)

        # TODO BJA : use findlines ?
        startDiv = selection.getLineDiv range.startContainer, range.startOffset
        endDiv = selection.getLineDiv range.endContainer, range.endOffset

        # Find first and last div corresponding to the first and last
        # selected lines
        startLineID = startDiv.id
        endLineID = endDiv.id

        lineStart = @_lines[startLineID]
        lineEnd   = @_lines[endLineID]
        linePrev  = lineStart.linePrev
        lineNext  = lineEnd.lineNext

        # if the first line selected (lineStart) isnt the very first line
        if linePrev != null

            # 0 - set boolean indicating if we are treating the second line
            isSecondLine = (linePrev.linePrev == null)

            # 1 - save linePrev
            cloneLine = Line.clone(linePrev)

            # 2 - Delete linePrev content then restore initial selection
            # TODO BJA : ensure this call don't pass a null param
            @_deleteMultiLinesSelections(linePrev.linePrev, linePrev)

            # 3 - Restore linePrev below the last selected line (lineEnd )
            # 3.1 - if isSecondLine, line objects must be fixed
            if isSecondLine
                # remove the hidden element inserted by deleteMultiLines
                $(linePrev.line$[0].firstElementChild).remove()
                # add the missing BR
                linePrev.line$.append '<br>'
                lineStart.line$ = linePrev.line$
                lineStart.line$.attr('id', lineStart.lineID)
                @_lines[lineStart.lineID] = lineStart

            # 4 - Modify the order of linking:
            #        lineStart--lineEnd--linePrev--lineNext
            linePrev = cloneLine
            @_lines[linePrev.lineID] = linePrev

            linePrev.lineNext = lineNext
            lineEnd.lineNext  = linePrev
            if linePrev.linePrev != null
                linePrev.linePrev.lineNext = lineStart
            lineStart.linePrev = linePrev.linePrev
            linePrev.linePrev  = lineEnd
            if lineNext != null
                lineNext.linePrev = linePrev

            # 5 - Replace the linePrev line in the DOM
            lineEnd.line$.after(linePrev.line$)

            # 6 - Re-insert linePrev after the end of the moved block.
            #     2 different configs of indentation may occur :
            # 6.1 - The swapped line (linePrev) is less indented than the
            #       block's last line (lineEnd)
            if linePrev.lineDepthAbs <= lineEnd.lineDepthAbs and lineNext!=null
                # find last line to untab
                line = linePrev
                while (line.lineNext!=null and
                       line.lineNext.lineDepthAbs>linePrev.lineDepthAbs)
                    line = line.lineNext
                if line.lineNext != null
                    line = line.lineNext
                # select the block from first line to untab (lineNext)
                # to last  line to untab (line)
                myRange = this.document.createRange()
                myRange.setStart(lineNext.line$[0], 0)
                myRange.setEnd(line.line$[0], 0)
                # untab this selected block.
                numOfUntab = lineNext.lineDepthAbs - linePrev.lineDepthAbs
                if linePrev.lineNext.lineType[0] == 'T'
                    # if linePrev is a 'T' and a 'T' follows, one untab less
                    if linePrev.lineType[0]=='T'
                        numOfUntab -= 1
                    # if linePrev is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1

                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1

            # 6.2 - The swapped line (linePrev) is more indented than
            #       the block's last line (lineEnd)
            else
                # untab linePrev
                myRange = this.document.createRange()
                myRange.setStart(linePrev.line$[0], 0)
                myRange.setEnd(linePrev.line$[0], 0)
                numOfUntab = linePrev.lineDepthAbs - lineEnd.lineDepthAbs

                if linePrev.lineType[0] == 'T'
                    # if lineEnd is a 'T' and a 'T' follows, one untab less
                    if lineEnd.lineType[0] == 'T'
                        numOfUntab -= 1
                    # if lineEnd is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1

                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1


    ###
    #  HISTORY MANAGEMENT:
    # 1. _addHistory (Save html code, selection markers, positions...)
    # 2. undoPossible (Return true only if unDo can be called)
    # 3. redoPossible (Return true only if reDo can be called)
    # 4. unDo (Undo the previous action)
    # 5. reDo ( Redo a undo-ed action)
    #
    # What is saved in the history:
    #  - current html content
    #  - current selection
    #  - current scrollbar position
    #  - the boolean newPosition
    ###

    ###* -----------------------------------------------------------------------
     *  Task history management

        time ------------------+------+---------------+-----------+-------->
        Tasks modified or      | T0c  | T0m T1c T2c   |  T1m T2m  |
        created                |      |               |           |
                               |      |               |           |
        History steps          H1     H2              H3          H4(*)
        history.modifiedTask        {T0c}       {T0m T1c T2c}   {T1m T2m}

        Ctrl-z                 H1     H2              H3(*)       H4
        _tasksToBeSaved                              {T1m,T2m}

        Ctrl-z                 H1     H2(*)           H3          H4
        _tasksToBeSaved              {T0m, T1d,T2d}

        Ctrl-z                 H1(*)  H2              H3          H4
        _tasksToBeSaved        {T0d, T1d,T2d}

        Ctrl-y                 H1     H2(*)           H3          H4
        _tasksToBeSaved              {T0m, T1d,T2d}

        Ctrl-y                 H1     H2              H3(*)       H4
        _tasksToBeSaved                              {T1m,T2m}

        Ctrl-y                 H1     H2              H3          H4(*)
        _tasksToBeSaved                                           {}

    ###



    ###* -----------------------------------------------------------------------
     * Add html, selection markers and scrollbar positions to the history.
     * No effect if the url popover is displayed
    ###
    _addHistory : () ->
        console.info '== _addHistory()'
        # do nothing if urlpopover is on, otherwise its html will also be
        # serialized in the history.
        if @isUrlPopoverOn or @_hotString.isPreparing
            return

        # 1- If some undo has been done, delete the steps forward (redo will
        # be then impossible)
        h = @_history
        if h.index < @HISTORY_SIZE - 1
            i = @HISTORY_SIZE - 1 - h.index
            while i--
                h.historySelect.pop()
                h.historyScroll.pop()
                h.historyPos.pop()
                h.history.pop()
                h.modifiedTask.pop()
                h.historySelect.unshift(undefined)
                h.historyScroll.unshift(undefined)
                h.historyPos.unshift(undefined)
                h.history.unshift(undefined)
                h.modifiedTask.unshift(undefined)

        # 2- save selection
        savedSel = @saveEditorSelection()
        h.historySelect.push savedSel

        # 3- save scrollbar position
        savedScroll =
            xcoord: @linesDiv.scrollTop
            ycoord: @linesDiv.scrollLeft
        h.historyScroll.push savedScroll

        # 4- save newPosition flag
        h.historyPos.push @newPosition

        # 5- add the html content with markers to the history
        h.history.push @linesDiv.innerHTML

        # 6- add the list of task modified since last addHistory()
        h.modifiedTask.push @_tasksModifSinceLastHistory
        # console.info '  last h.modifiedTask', h.modifiedTask[@HISTORY_SIZE]
        @_tasksModifSinceLastHistory = {}

        # 7- update the index
        h.index = @HISTORY_SIZE - 1

        # 8- drop oldest history step
        h.historySelect.shift()
        h.historyScroll.shift()
        h.historyPos.shift()
        h.history.shift()
        h.modifiedTask.shift()

        # @__printHistory('_addHistory')


    # _initHistory : () ->
    #     HISTORY_SIZE  = @HISTORY_SIZE
    #     h = @_history
    #     h.history       = new Array(HISTORY_SIZE)
    #     h.historySelect = new Array(HISTORY_SIZE)
    #     h.historyScroll = new Array(HISTORY_SIZE)
    #     h.historyPos    = new Array(HISTORY_SIZE)
    #     h.modifiedTask  = new Array(HISTORY_SIZE)
    #     @._addHistory()

    _removeLastHistoryStep : () ->
        h = @_history
        h.historySelect.pop()
        h.historyScroll.pop()
        h.historyPos.pop()
        h.history.pop()
        h.modifiedTask.pop()
        h.historySelect.unshift(undefined)
        h.historyScroll.unshift(undefined)
        h.historyPos.unshift(undefined)
        h.history.unshift(undefined)
        h.modifiedTask.unshift(undefined)
        h.index = @HISTORY_SIZE - 1

    ### ------------------------------------------------------------------------
    #  undoPossible
    # Return true only if unDo can be called
    ###
    undoPossible : () ->
        i = @_history.index
        return (i >= 0 && @_history.historyPos[i] != undefined )

    ### ------------------------------------------------------------------------
    #  redoPossible
    # Return true only if reDo can be called
    ###
    redoPossible : () ->
        return (@_history.index < @_history.history.length-2)


    ###*------------------------------------------------------------------------
     * Undo the previous action
    ###
    unDo : () ->
        # if there is an action to undo
        if @undoPossible() and @isEnabled
            if @_hotString.isPreparing
                @_hotString.reset(false)
            @_forceUndo()
            @newPosition = true
            # @_lastKey = null # to force addhistory on next action

    _forceUndo : () ->
        console.info "\n== UNDO :"
        h = @_history
        # if we are in an unsaved state
        if h.index == h.history.length-1
            # save current state
            @_addHistory()
            # re-evaluate index
            h.index -= 1

        stepIndex = h.index

        # 1- restore newPosition
        @newPosition = h.historyPos[stepIndex]

        # 2- restore html
        if @isUrlPopoverOn
            @_cancelUrlPopover(false)
        @linesDiv.innerHTML = h.history[stepIndex]

        # 3- restore selection
        savedSel = h.historySelect[stepIndex]
        if savedSel
            @deSerializeSelection(savedSel)

        # 4- restore scrollbar position
        savedScroll = h.historyScroll[stepIndex]
        @linesDiv.scrollTop = savedScroll.xcoord
        @linesDiv.scrollLeft = savedScroll.ycoord

        # 5- restore the lines structure
        @_readHtml()

        # 6 - stack the tasks that have been impacted by undo so that
        # saveTasks() take them into account.
        for id, modif of h.modifiedTask[stepIndex+1]
            console.info modif.a
            switch modif.a
                when 'modified'
                    @_stackTaskForSave(id, modif.t, 'modified')
                when 'deleted'
                    @_stackTaskForSave(id, modif.t, 'created')
                else
                    console.info 'marking as deleted in undo'
                    @_stackTaskForSave(id, modif.t, 'deleted')

        # 7- Restore the tasks that that were not impacted by the undo &
            # redo (because the task might have changed on the server side and
            # ctrl-Z / ctrl-y should not modify those tasks)
        for t in @_taskList
            # check the task is not modified by one of the step of history that
            # have been backward
            if t.isFromServer
                @_updateTaskLine t


            # i = stepIndex + 1
            # isInHistory = false
            # while @HISTORY_SIZE - i
            #     modifs = h.modifiedTask[i]
            #     i++
            #     for id of modifs
            #         if id == t.internalId
            #             i = @HISTORY_SIZE
            #             isInHistory = true
            #             break
            # if !isInHistory
            #     console.info 'here'
            #     @_updateTaskLine(t)

        @__printTasksModifStacks()

        # 8- update the index
        h.index -= 1

        # @__printHistory('unDo')



    ###* -----------------------------------------------------------------------
     * Redo a undo-ed action
    ###
    reDo : () ->
        console.info "\n== REDO :"
        h = @_history
        # if there is an action to redo
        if @redoPossible() and @isEnabled

            # 0- update the index
            index = (h.index += 1)
            # i == index of stpe to redo
            i = index + 1

            # restore newPosition
            @newPosition = h.historyPos[i]

            # 1- restore html
            if @isUrlPopoverOn
                @_cancelUrlPopover(false)
            @linesDiv.innerHTML = h.history[i]

            # 2- restore selection
            savedSel = h.historySelect[i]
            if savedSel
                @deSerializeSelection(savedSel)

            # 3- restore scrollbar position
            xcoord = h.historyScroll[i].xcoord
            ycoord = h.historyScroll[i].ycoord
            @linesDiv.scrollTop = xcoord
            @linesDiv.scrollLeft = ycoord

            # 4 - restore lines structure
            @_readHtml()

            # 5 - stack the tasks that have been impacted by redo so that
            # saveTasks() take them into account.
            for id, modif of h.modifiedTask[index+1]
                @_stackTaskForSave(id, modif.t, modif.a)

            # 6- Restore the ui of tasks that that were not impacted by the undo
            # &  redo (because the task might have changed on the server side
            # and ctrl-Z / ctrl-y should not modify those tasks)
            for t in @_taskList
                # check the task is not modified by one of the step of history
                # that have been backward
                if t.isFromServer
                    @_updateTaskLine(t)

                # i = index + 1
                # isInHistory = false
                # while @HISTORY_SIZE - i
                #     modifs = h.modifiedTask[i]
                #     i++
                #     for id, modif of modifs
                #         if id == t.internalId
                #             i = @HISTORY_SIZE
                #             isInHistory = true
                #             break
                # if !isInHistory
                #     @_updateTaskLine(t)

            # to force addhistory on next action
            # @_lastKey = null
            @newPosition = true


            # @__printHistoryModifiedTask()
            @__printTasksModifStacks()

            # console.info 'reDo', h.index
            # @__printHistory('reDo')



    _replaceInTaskHistory : (task) ->
        i = @HISTORY_SIZE
        while i--
            modif = @_history.modifiedTask[i]
            if !modif
                return
            if modif[task.internalId]
                modif[task.internalId].t = task


    ###* -----------------------------------------------------------------------
     * A utility fuction for debugging
     * @param  {string} txt A text to print in front of the log
    ###
    __printHistory : (txt) ->
        if ! txt
            txt = ''
        console.info txt + ' _history.index : ' + @._history.index
        for step, i in @._history.history
            if @._history.index == i
                arrow = ' <---'
            else
                arrow = ' '
                content = $(step).text()
                content = '_' if content == ''
            console.info i, content , @._history.historySelect[i] , arrow
        return true


    ###* -----------------------------------------------------------------------
     * A utility fuction for debugging
     * @param  {string} txt A text to print in front of the log
    ###
    __printTasksModifStacks : (txt) ->
        if ! txt
            txt = ''
        res =  '  _tasksToBeSaved : '
        for id, modif of @._tasksToBeSaved
            res += id + ':'
            if modif.created
                res += 'created-'
            if modif.modified
                res += 'modified-'
            if modif.deleted
                res += 'deleted-'
            if modif.removed
                res += 'removed-'
            res = res.slice(0,-1)
            res +=  ', '
        res = res.slice(0,-2)
        console.info res
        return true


    ###* -----------------------------------------------------------------------
     * Deserialize a range and return it.
     * @param  {String} serial   A string corresponding to a serialized range.
     * @param  {element} rootNode The root node used for the serialization
     * @return {range}          The expected range
    ###
    deSerializeRange : (serial, rootNode) ->
        if !rootNode
            rootNode = this.linesDiv
        range = rootNode.ownerDocument.createRange()
        serials = serial.split(',')
        startPath = serials[0].split('/')
        endPath   = serials[1].split('/')

        # deserialize start breakpoint
        startCont = rootNode
        i = startPath.length
        while --i
            parentCont = startCont
            startCont = startCont.childNodes[ startPath[i] ]
        offset = parseInt(startPath[i], 10)
        # it happens that an empty text node has been removed : in this case,
        # startCont is null and offset == 0. In this case insert a text node.
        if !startCont and offset == 0
            startCont = document.createTextNode('')
            parentCont.appendChild(startCont)
        range.setStart(startCont,offset)

        # deserialize end breakpoint
        endCont = rootNode
        i = endPath.length
        while --i
            parentCont = endCont
            endCont = endCont.childNodes[ endPath[i] ]
        offset = parseInt(endPath[i], 10)
        # it happens that an empty text node has been removed : in this case,
        # startCont is null and offset == 0. In this case insert a text node.
        if !endCont and offset == 0
            endCont = document.createTextNode('')
            parentCont.appendChild(endCont)
        range.setEnd(endCont,offset)

        return range

    ###* -----------------------------------------------------------------------
     * Serialize a range.
     * The breakpoint are 2 strings separated by a comma.
     * Structure of a serialized bp : {offset}{/index}*
     * Global struct : {startOffset}{/index}*,{endOffset}{/index}*
     * @param  {Range} range    The range to serialize
     * @param  {element} rootNode [optional] the root used for serialization.
     *                            If none, we use the body of the ownerDocument
     *                            of range.startContainer
     * @return {String}          The string, exemple : "10/0/2/1,3/1", or false
     *                           if the rootNode is not a parent of one of the
     *                           range's break point.
    ###
    serializeRange : (range, rootNode) ->
        if !rootNode
            rootNode = this.linesDiv

        # serialise start breakpoint
        res  = range.startOffset
        node = range.startContainer
        while node != null and node != rootNode
            i = 0
            sib = node.previousSibling
            while sib != null
                i++
                sib = sib.previousSibling
            res += '/' + i
            node = node.parentNode

        if node == null
            return false

        # serialise end breakpoint
        res += ',' + range.endOffset
        node = range.endContainer
        while node != null and node != rootNode
            i = 0
            sib = node.previousSibling
            while sib != null
                i++
                sib = sib.previousSibling
            res += '/' + i
            node = node.parentNode

        if node == null
            return false

        return res

    serializeSel : () ->
        s = this.document.getSelection()
        if s.rangeCount == 0
            return false
        return @serializeRange(s.getRangeAt(0))

    deSerializeSelection : (serial) ->
        sel = this.document.getSelection()
        sel.removeAllRanges()
        sel.addRange(@.deSerializeRange(serial))


    ### ------------------------------------------------------------------------
    # EXTENSION  :  auto-summary management and upkeep
    #
    # initialization
    # TODO: avoid updating the summary too often
    #       it would be best to make the update faster (rather than reading
    #       every line)
    ###
    _initSummary : () ->
        summary = @editorBody$.children("#navi")
        if summary.length == 0
            summary = $ document.createElement('div')
            summary.attr('id', 'navi')
            summary.prependTo @editorBody$
        return summary

    # Summary upkeep
    _buildSummary : () ->
        summary = @initSummary()
        @editorBody$.children("#navi").children().remove()
        lines = @_lines
        for c of lines
            if (@editorBody$.children('#' + "#{lines[c].lineID}").length > 0   \
                  and lines[c].lineType == "Th")
                lines[c].line$.clone().appendTo summary


    ### ------------------------------------------------------------------------
    #  EXTENSION  :  DECORATION FUNCTIONS (bold/italic/underlined/quote)
    #  TODO
    ###


    ### ------------------------------------------------------------------------
    #  PASTE MANAGEMENT
    # 0 - save selection
    # 1 - move the cursor into an invisible sandbox
    # 2 - redirect pasted content in this sandox
    # 3 - sanitize and adapt pasted content to the editor's format
    # 4 - restore selection
    # 5 - insert cleaned content is behind the cursor position
    ###
    paste : (event) ->
        # init the div where the paste will actualy accur.
        mySandBox = @clipboard
        # save current selection in this.currentSel
        @updateCurrentSelIsStartIsEnd()
        # move caret into the sandbox
        range = this.document.createRange()
        range.selectNodeContents mySandBox
        sel = @getEditorSelection()
        sel.removeAllRanges()
        sel.addRange(range)
        range.detach()
        # check whether the browser is a Webkit or not
        if event and event.clipboardData and event.clipboardData.getData
            # Webkit: 1 - get data from clipboard
            #         2 - put data in the sandbox
            #         3 - clean the sandbox
            #         4 - cancel event (otherwise it pastes twice)

            if event.clipboardData.types == "text/html"
                mySandBox.innerHTML = event.clipboardData.getData('text/html')
            else if event.clipboardData.types == "text/plain"
                mySandBox.innerHTML = event.clipboardData.getData('text/plain')
            else
                mySandBox.innerHTML = ""
            @_waitForPasteData mySandBox
            if event.preventDefault
                event.stopPropagation()
                event.preventDefault()
            return false
        else
            # not a Webkit: 1 - empty the sandBox
            #               2 - paste in sandBox
            #               3 - cleanup the sandBox
            # mySandBox.innerHTML = ""
            @_waitForPasteData mySandBox
            return true



    ###* -----------------------------------------------------------------------
    # * init the div where the browser will actualy paste.
    # * this method is called after each refresh of the content of the editor (
    # * replaceContent, deleteContent, setEditorContent)
    # * TODO : should be called just once at editor init : for this the editable
    # * content shouldn't be directly in the body of the iframe but in a div.
    # * @return {obj} a ref to the clipboard div
    ###
    _initClipBoard : () ->
        clipboardEl = document.createElement('div')
        clipboardEl.contentEditable = true
        clipboardEl.id = 'editor-clipboard'
        @clipboard$ = $(clipboardEl)
        getOffTheScreen =
            left: -300
        @clipboard$.offset getOffTheScreen
        @clipboard$.prependTo @editorBody$
        @clipboard = @clipboard$[0]
        clipboardEl.style.setProperty('width','10px')
        clipboardEl.style.setProperty('height','10px')
        clipboardEl.style.setProperty('position','fixed')
        clipboardEl.style.setProperty('overflow','hidden')
        return clipboardEl



    ###* -----------------------------------------------------------------------
     * Function that will call itself until the browser has pasted data in the
     * clipboar div
     * @param  {element} sandbox      the div where the browser will paste data
     * @param  {function} processpaste the function to call back whan paste
     * is ok
    ###
    _waitForPasteData : =>
    # if the clipboard div has child => paste is done => can continue
        if @clipboard.childNodes and @clipboard.childNodes.length > 0
            @_processPaste()
        # else : paste not ready => wait
        else
            setTimeout @_waitForPasteData, 100


    ###* -----------------------------------------------------------------------
     * Called when the browser has pasted data in the clipboard div.
     * Its role is to insert the content of the clipboard into the editor.
    ###
    _processPaste : () =>
        sandbox = @.clipboard
        currSel = @currentSel

        # 1- Sanitize clipboard content with node-validator
        # (https://github.com/chriso/node-validator)
        # may be improved with google caja sanitizer :
        # http://code.google.com/p/google-caja/wiki/JsHtmlSanitizer
        sandbox.innerHTML = sanitize(sandbox.innerHTML).xss()

        # 2- Prepare a fragment where the lines (<div id="CNID_xx" ... </div>)
        # will be prepared before to be inserted in the editor.
        # _insertLineAfter() will work to insert new lines in the frag and
        # will correctly update the editor. For that we insert a dummyLine
        # at the beginning so that the first insertLineAfter works.
        frag = document.createDocumentFragment()
        dummyLine =
            lineNext : null
            linePrev : null
            line$    : $("<div id='dummy' class='Tu-1'></div>")
        frag.appendChild(dummyLine.line$[0])

        # 3- _domWalk will parse the clipboard in order to insert lines in frag.
        # Each line will be prepared in its own fragment before being inserted
        # into frag.
        # _domWalk is recursive and the variables of the context of the parse
        # are stored in the parameter "domWalkContext" that is transmited at
        # each recursion.
        currentLineFrag = document.createDocumentFragment()
        absDepth = currSel.startLine.lineDepthAbs
        if currSel.startLine.lineType == 'Th'
            absDepth += 1
        domWalkContext =
            # The fragment where new lines will be added during the parse of the
            # clipboard div
            frag               : frag,
            # Refers to the last inserted line in the frag
            lastAddedLine      : dummyLine,
            # Fragment where a line is under construction
            currentLineFrag    : currentLineFrag,
            # Element (or node) of currentLineFrag being populated by _domWalk
            currentLineEl      : currentLineFrag,
            # Absolute depth of the current explored node of clip board
            absDepth           : absDepth,
            # Level of the Previous  <hx> element (ex : if last title parsed
            # was h3 => prevHxLevel==3)
            prevHxLevel        : null,
            # Previous Cozy Note Line Abs Depth, used for the insertion of
            # internal lines with  _clipBoard_Insert_InternalLine()
            prevCNLineAbsDepth : null,
            # Boolean wether currentLineFrag has already had an
            # element appended.
            isCurrentLineBeingPopulated : false

        # go for the walk !
        htmlStr = @_domWalk sandbox, domWalkContext

        # empty the clipboard div
        sandbox.innerHTML = ""
        # delete dummy line from the fragment
        frag.removeChild(frag.firstChild)

        ###
        # TODO : the following steps removes all the styles of the lines in frag
        # Later this will be removed in order to take into account styles.
        ###
        # for line in frag.childNodes.length
        #     line = frag.childNodes[i]
        #     txt = line.textContent
        #     line.innerHTML = '<span></span><br>'
        #     line.firstChild.appendChild(document.createTextNode(txt))
        ###
        # END TODO
        ###

        # 4- Delete the selections so that the selection is collapsed
        startLine = currSel.startLine
        endLine   = currSel.endLine
        if currSel.range.collapsed
            # nothing to do
        else if endLine == startLine
            currSel.range.deleteContents()
            # in case deleteContent left a span without text node
            selection.normalize(currSel.range)
        else
            @_deleteMultiLinesSelections()
            selection.normalize(currSel.range)
            @newPosition = true # in order to force normalization
            currSel = @updateCurrentSelIsStartIsEnd()
            @newPosition = false
            startLine = currSel.startLine

        ### 5- Insert first line of the frag in the target line
        # We assume that the structure of lines in frag and in the editor are :
        #   <div><span>(TextNode)</span><br></div>
        # what will be incorrect when styles will be taken into account.
        #
        ###
        # a text node because of selection.normalize()
        targetNode   = currSel.theoricalRange.startContainer
        startOffset  = currSel.theoricalRange.startOffset
        # the break point to update in order to be able to positionate the caret
        # at the end
        bp =
            cont   : targetNode
            offset : startOffset

        # prepare lineElements of the first line
        if frag.childNodes.length > 0
            lineElements = Array.prototype.slice.call(
                frag.firstChild.childNodes)
            lineElements.pop() # remove the </br>
        else
            # ?? in which case do we come here ? please document...
            lineElements = [frag]

        # loop on each element to insert (only one for now)
        for segToInsert in lineElements
            @_insertSegment(segToInsert,bp)
        if bp.cont.nodeName != '#text'
            bp = selection.normalizeBP(bp.cont,bp.offset,true)

        @_fusionSimilarSegments(startLine.line$[0], [bp])

        # targetNode and startOffset may have been removed from the DOM while
        # inserting first line of frag. We then have to set them again at the
        # end of what has already been inserted
        targetNode = bp.cont
        startOffset = bp.offset

        ###
        # 6- If the clipboard has more than one line, insert the end of target
        #    line in the last line of frag and delete it
        ###
        if frag.childNodes.length > 1
            range = document.createRange()
            range.setStart(targetNode,startOffset)
            parendDiv = targetNode
            while parendDiv.tagName != 'DIV'
                parendDiv = parendDiv.parentElement
            range.setEnd(parendDiv,parendDiv.children.length-1)
            endTargetLineFrag = range.extractContents()
            range.detach()

            # append the frag content
            lastFragLine = frag.lastChild
            br = lastFragLine.lastChild
            n  = lastFragLine.childNodes.length-1
            bp = selection.normalizeBP(lastFragLine, n)
            childNodes = endTargetLineFrag.childNodes
            l = childNodes.length
            for n in [1..l] by 1
                lastFragLine.insertBefore(childNodes[0],br)
            @_fusionSimilarSegments(lastFragLine, [bp])

            # TODO : the next 3 lines are required for firebug to detect
            # breakpoints ! ! !   ???????? (otherwise could be deleted)
            parendDiv = targetNode
            while parendDiv.tagName != 'DIV'
                parendDiv = parendDiv.parentElement
        ###
         * remove the firstAddedLine from the fragment
        ###
        firstAddedLine = dummyLine.lineNext
        secondAddedLine = firstAddedLine?.lineNext
        if frag.firstChild?
            frag.removeChild(frag.firstChild)
        if firstAddedLine?
            delete this._lines[firstAddedLine.lineID]

        ###
         * 7- updates nextLine and prevLines, insert frag in the editor
        ###
        if secondAddedLine?
            lineNextStartLine          = currSel.startLine.lineNext
            currSel.startLine.lineNext = secondAddedLine
            secondAddedLine.linePrev   = currSel.startLine
            if lineNextStartLine == null
                @linesDiv.appendChild(frag)
            else
                domWalkContext.lastAddedLine.lineNext = lineNextStartLine
                lineNextStartLine.linePrev = domWalkContext.lastAddedLine
                @linesDiv.insertBefore(frag, lineNextStartLine.line$[0])
        ###
         * 8- Adapt lines depth and type.
        ###
        lastAdded = domWalkContext.lastAddedLine
        if lastAdded.lineNext
            lastAddedDepth = lastAdded.lineDepthAbs
            startLineDepth = startLine.lineDepthAbs
            deltaInserted  = startLineDepth - lastAddedDepth
            currentDelta   = lastAdded.lineNext.lineDepthAbs - lastAddedDepth
            @_adaptDepth(
                domWalkContext.lastAddedLine,  # startLine
                deltaInserted,                 # deltaInserted
                currentDelta,                  # currentDelta
                lastAddedDepth  )              # minDepth
            @_adaptType(currSel.startLine)

        ###
         * 9- position caret
        ###
        bp = @_setCaret(bp.cont,bp.offset)


    ###* -----------------------------------------------------------------------
     * Insert segment at the position of the breakpoint.
     * /!\ The bp is updated but not normalized. The break point will between 2
     * segments if the insertion splits a segment in two. This is normal. If you
     * want to have a break point normalized (ie in a text node), then you have
     * to do it afterwards.
     * /!\ If the inserted segment should be fusionned with its similar sibling,
     * you have to run _fusionSimilarSegments() over the whole line after the
     * insertion.
     * @param  {element} segment The segment to insert
     * @param  {Object} bp      {cont, offset} resp. the container and offset of
     *                          the breakpoint where to insert segment. The
     *                          breakpoint must be in a segment, ie cont or one
     *                          of its parent must be a segment.
    ###
    _insertSegment : (newSeg,bp) ->
        targetNode = bp.cont
        targetSeg  = selection.getSegment(targetNode)
        # If targetSeg & newSeg have the same meta data => concatenate

        if targetSeg.nodeName == 'DIV'
            targetSeg.insertBefore(newSeg,targetSeg.children[bp.offset])
            bp.offset++

        else if newSeg.nodeName == 'SPAN'
            if targetSeg.nodeName == 'A' or @_haveSameMeta(targetSeg,newSeg)
                @_insertTextInSegment(newSeg.textContent, bp, targetSeg )
            else
                @_splitAndInsertSegment(newSeg, bp, targetSeg)

        else if @_haveSameMeta(targetSeg,newSeg)
            @_insertTextInSegment(newSeg.textContent, bp, targetSeg)

        else
            @_splitAndInsertSegment(newSeg, bp, targetSeg)

        return true


    _insertTextInSegment : (txt, bp, targetSeg) ->
        if txt == ''
            return true

        if !targetSeg
            targetSeg = selection.getSegment(bp.cont)
        targetText = targetSeg.textContent
        offset = bp.offset
        newText  = targetText.substr(0,offset)
        newText += txt
        newText += targetText.substr(offset)
        targetSeg.textContent = newText
        offset += txt.length
        bp.cont = targetSeg.firstChild
        bp.offset = offset
        return true

    _splitAndInsertSegment : (newSegment, bp, targetSeg) ->
        if !targetSeg
            targetSeg = selection.getSegment(bp.cont)
        rg = document.createRange()
        rg.setStart(bp.cont,bp.offset)
        rg.setEndAfter(targetSeg)
        frag = rg.extractContents()
        frag.insertBefore(newSegment,frag.firstChild)
        targetSeg.parentNode.insertBefore(frag,targetSeg.nextSibling)
        bp.cont = targetSeg.parentNode
        i = 0
        children = bp.cont.childNodes
        while children[i] != targetSeg
            i++
        bp.offset = i + 2

    ###*
     * insert an segment with one space caractère after a given segment.
     * @param  {Element} seg The segment after whiche we will insert
     * @return {Element}     The created segment
    ###
    _insertSegmentAfterSeg : (seg) ->
        span = document.createElement('SPAN')
        txt = document.createTextNode('\u00a0')
        span.appendChild(txt)
        seg.parentElement.insertBefore(span,seg.nextSibling)
        return span

    ###*
     * returns a break point, collapsed after a space caracter immediately
     * following a given segment. A segment will we inserted if required.
     * @param  {[type]} seg [description]
     * @return {[type]}     [description]
    ###
    insertSpaceAfterSeg : (seg) ->
        nextSeg = seg.nextSibling
        if nextSeg.nodeName == 'BR'
            span = @_insertSegmentAfterSeg(seg)
            bp = {cont:span.firstChild, offset:1}
        else
            index = selection.getSegmentIndex(seg)[1] + 1
            bp = selection.normalizeBP(seg.parentElement, index, true)
            txtNode = bp.cont
            c1 = txtNode.textContent[0]
            if !(c1 == ' ' or c1 == '\u00a0')
                txtNode.textContent = '\u00a0' + txtNode.textContent
            bp.offset = 1
        return bp


    ###*
     * returns a break point, collapsed after a space caracter immediately
     * following a given segment. A segment will we inserted if required.
     * @param  {[type]} seg [description]
     * @return {Object}     {cont,offset} : the break point
    ###
    insertSpaceAfterUrl : (seg) ->
        nextSeg = seg.nextSibling
        if nextSeg.nodeName == 'BR'
            span = @_insertSegmentAfterSeg(seg)
            bp = {cont:span.firstChild, offset:1}
        else
            index = selection.getSegmentIndex(seg)[1] + 1
            bp = selection.normalizeBP(seg.parentElement, index, true)
            txtNode = bp.cont
            # c1 = txtNode.textContent[0]
            # if c1 != ' ' and c1 != '\u00a0'
            #     txtNode.textContent = '\u00a0' + txtNode.textContent
            # bp.offset = 1
            bp.offset = 0
        return bp


    ###* -----------------------------------------------------------------------
     * Walks thoug an html tree in order to convert it in a strutured content
     * that fit to a note structure.
     * @param  {html element} elemt   Reference to an html element to be parsed
     * @param  {object} context context of execution of _domWalk (recursive).
    ###
    _domWalk : (elemt, context) ->
        this.__domWalk(elemt, context)
        # if a line was being populated, append it to the frag
        if context.currentLineFrag.childNodes.length > 0
            p =
                sourceLine         : context.lastAddedLine
                fragment           : context.currentLineFrag
                targetLineType     : "Tu"
                targetLineDepthAbs : context.absDepth
                targetLineDepthRel : context.absDepth
            context.lastAddedLine = @_insertLineAfter(p)


    ###* -----------------------------------------------------------------------
     * Walks thoug an html tree in order to convert it in a strutured content
     * that fit to a note structure.
     * @param  {html element} nodeToParse   Reference to an html element to
     *                        be parsed
     * @param  {object} context __domWalk is recursive and its context of
     *                          execution is kept in this param instead of
     *                          using the editor context (faster and better
     *                          isolation)
    ###
    __domWalk : (nodeToParse, context) ->
        absDepth    = context.absDepth
        prevHxLevel = context.prevHxLevel

        # loop on the child nodes of the parsed node
        for child in nodeToParse.childNodes
            switch child.nodeName

                when '#text'
                    # text nodes are inserted in the current populated
                    # element if its a "textual" element
                    if context.currentLineEl.nodeName in ['SPAN','A']
                        context.currentLineEl.textContent += child.textContent
                    # otherwise in a new span
                    else
                        txtNode = document.createTextNode(child.textContent)
                        spanEl = document.createElement('span')
                        spanEl.appendChild txtNode
                        context.currentLineEl.appendChild spanEl

                    context.isCurrentLineBeingPopulated = true

                when 'P', 'UL', 'OL'
                    # we have to insert the current line and create a new on for
                    # the content of this child.
                    context.absDepth = absDepth
                    @__domWalk(child,context )
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,absDepth,absDepth)

                when 'H1','H2','H3','H4','H5','H6'
                    # if prevHxLevel == null
                    #     prevHxLevel = +child.nodeName[1]-1
                    # newHxLevel = +child.nodeName[1]
                    # deltaHxLevel = newHxLevel-prevHxLevel
                    deltaHxLevel =0

                    @__domWalk(child, context)
                    # if a line was being populated, append it to the frag
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,
                                                Math.min(0,deltaHxLevel) + absDepth,
                                                Math.min(0,deltaHxLevel) + absDepth
                            )

                    # TODO : for depth
                    # if deltaHxLevel > 0
                    #     absDepth             = absDepth+1
                    #     context.absDepth     = absDepth
                    #     prevHxLevel          = newHxLevel
                    #     context.prevHxLevel  = newHxLevel
                    # else
                    #     absDepth             = absDepth+deltaHxLevel+1 # TODO put a min
                    #     context.absDepth     = absDepth
                    #     prevHxLevel          = newHxLevel
                    #     context.prevHxLevel  = newHxLevel

                when 'LI'
                    # if a line was being populated, append it to the frag
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,absDepth,absDepth)
                    # walk throught the child and append it to the frag
                    @__domWalk(child, context)
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,absDepth,absDepth)

                when 'TR'
                    # if a line was being populated, append it to the frag
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,absDepth,absDepth)
                    # walk throught the child and append it to the frag
                    @__domWalk(child, context)
                    if context.isCurrentLineBeingPopulated
                        @_appendCurrentLineFrag(context,absDepth,absDepth)

                when 'BR'
                    # append the line that was being populated to the frag (even
                    # if this one had not yet been populated by any element)
                    @_appendCurrentLineFrag(context,absDepth,absDepth)

                when 'A'
                    # without <a> element :
                    # lastInsertedEl = context.currentLineEl.lastChild
                    # if lastInsertedEl != null and lastInsertedEl.nodeName=='SPAN'
                    #     lastInsertedEl.textContent += '[' + child.textContent + ']('+ child.href+')'
                    # else
                    #     spanNode = document.createElement('span')
                    #     spanNode.textContent = child.textContent + ' [[' + child.href+']] '
                    #     context.currentLineEl.appendChild(spanNode)
                    # context.isCurrentLineBeingPopulated = true

                    # with <a> element :
                    aNode = document.createElement('a')
                    aNode.textContent = child.textContent
                    aNode.href        = child.href
                    context.currentLineEl.appendChild(aNode)


                    # if context.currentLineEl.nodeName == 'A'
                    #     context.currentLineEl.textContent += child.textContent
                    # # otherwise in a new span
                    # else
                    #     txtNode = document.createTextNode(child.textContent)
                    #     spanEl = document.createElement('span')
                    #     spanEl.appendChild txtNode
                    #     context.currentLineEl.appendChild spanEl

                    # context.isCurrentLineBeingPopulated = true


                # ###
                # ready for styles to be taken into account
                # when 'A'
                #     # insert a <a> in the currentLineFrag
                #     aNode = document.createElement('a')
                #     initialCurrentLineEl = context.currentLineEl
                #     context.currentLineEl.appendChild(aNode)
                #     context.currentLineEl = aNode
                #     @__domWalk(child, context)
                #     context.currentLineEl = initialCurrentLineEl
                #     context.isCurrentLineBeingPopulated = true
                # when 'B','STRONG'
                #     # insert a <span> in the currentLineFrag
                #     spanNode = document.createElement('strong')
                #     initialCurrentLineEl = context.currentLineEl
                #     context.currentLineEl.appendChild(spanNode)
                #     context.currentLineEl = spanNode
                #     result += @__domWalk(child, context)
                #     context.currentLineEl = initialCurrentLineEl
                #     context.isCurrentLineBeingPopulated = true
                # when 'I','EM'
                #     # insert a <span> in the currentLineFrag
                #     spanNode = document.createElement('EM')
                #     initialCurrentLineEl = context.currentLineEl
                #     context.currentLineEl.appendChild(spanNode)
                #     @__domWalk(child, context)
                #     context.currentLineEl = initialCurrentLineEl
                #     context.isCurrentLineBeingPopulated = true
                # when 'SPAN'
                #     # insert a <span> in the currentLineFrag
                #     spanNode = document.createElement('span')
                #     initialCurrentLineEl = context.currentLineEl
                #     context.currentLineEl = spanNode
                #     context.currentLineFrag.appendChild(spanNode)
                #     @__domWalk(child, context)
                #     context.currentLineEl = initialCurrentLineEl
                #     context.isCurrentLineBeingPopulated = true
                when 'DIV', 'TABLE', 'TBODY'
                    if child.id.substr(0,5)=='CNID_'
                        @_clipBoard_Insert_InternalLine(child, context)
                    else
                        @__domWalk(child, context)
                else
                    lastInsertedEl = context.currentLineEl.lastChild
                    if lastInsertedEl != null && lastInsertedEl.nodeName=='SPAN'
                        lastInsertedEl.textContent += child.textContent
                    else
                        spanNode = document.createElement('span')
                        spanNode.textContent = child.textContent
                        classes = child.classList
                        newClass = ''
                        for clas in classes
                            if clas.slice(0,3) == 'CNE'
                                newClass += ' ' + clas
                        spanNode.className = newClass
                        context.currentLineEl.appendChild(spanNode)
                    context.isCurrentLineBeingPopulated = true

        true



    ###* -----------------------------------------------------------------------
     * Append to frag the currentLineFrag and prepare a new empty one.
     * @param  {Object} context  [description]
     * @param  {Number} absDepth absolute depth of the line to insert
     * @param  {Number} relDepth relative depth of the line to insert
    ###
    _appendCurrentLineFrag : (context,absDepth,relDepth) ->
        # if the line is empty, add an empty Span before the <br>
        if context.currentLineFrag.childNodes.length == 0
            spanNode = document.createElement('span')
            spanNode.appendChild(document.createTextNode(''))
            context.currentLineFrag.appendChild(spanNode)

        p =
            sourceLine         : context.lastAddedLine
            fragment           : context.currentLineFrag
            targetLineType     : "Tu"
            targetLineDepthAbs : absDepth
            targetLineDepthRel : relDepth
        context.lastAddedLine = @_insertLineAfter(p)
        # prepare the new lingFrag & lineEl
        context.currentLineFrag = document.createDocumentFragment()
        context.currentLineEl = context.currentLineFrag
        context.isCurrentLineBeingPopulated = false



    ###* -----------------------------------------------------------------------
     * Insert in the editor a line that was copied in a cozy note editor
     * @param  {Element} elemt A div
     *                         ex : <div id="CNID_7" class="Lu-3"> ... </div>
     * @return {Line}          A ref to the line object
    ###
    _clipBoard_Insert_InternalLine : (elemt, context)->
        lineClass = elemt.className.split('-')
        lineDepthAbs = +lineClass[1]
        lineClass = lineClass[0]

        if !context.prevCNLineAbsDepth
            context.prevCNLineAbsDepth = lineDepthAbs
        deltaDepth = lineDepthAbs - context.prevCNLineAbsDepth
        if deltaDepth > 0
            context.absDepth += 1
        else
            context.absDepth += deltaDepth
            context.absDepth = Math.max(1,context.absDepth)
        context.prevCNLineAbsDepth = lineDepthAbs

        elemtFrag = document.createDocumentFragment()
        n = elemt.childNodes.length
        i = 0
        while i < n
            seg = elemt.childNodes[0]
            # sometimes, the paste of the browser removes span and leave only a
            # text node : then we have to add the span.
            if seg.nodeName == '#text'
                span = document.createElement('SPAN')
                span.appendChild(seg)
                elemtFrag.appendChild(span)
            else
                elemtFrag.appendChild(seg)
            i++
        p =
            sourceLine         : context.lastAddedLine
            fragment           : elemtFrag
            targetLineType     : lineClass # "Tu"
            targetLineDepthAbs : context.absDepth
            targetLineDepthRel : context.absDepth
        context.lastAddedLine = @_insertLineAfter(p)


    ###*
     * Called by the hotString controler when return is hit or when an item of
     * the auto complete is clicked.
     * @param  {Object} autoItem
     *                  {text:'value', type:'reminder'|'contact'|..., value:{}}
    ###
    doHotStringAction : (autoItem) ->

        hs = @_hotString

        if !autoItem
            hs.reset('end')
            return true

        switch autoItem.type

            when 'ttag'
                switch autoItem.value
                    when 'todo'
                        return @doHotStringAction(type:'todo')

                    when 'htag'
                        hs._forceUserHotString('#', [])
                        hs.updateHs()
                        bp = selection.normalizeBP(hs._hsSegment, 1)
                        @_setCaret(bp.cont, bp.offset)
                        return true

                    when 'reminder'
                        hs._forceUserHotString('@@', [])
                        hs.updateHs()
                        bp = selection.normalizeBP(hs._hsSegment, 1)
                        @_setCaret(bp.cont, bp.offset)
                        return true

            when 'todo'
                taskDiv = @._turnIntoTask()
                if taskDiv
                    txt = taskDiv.textContent.trim()
                    reg = new RegExp('^ *@?t?o?d?o? *$','i')
                    if txt.match(reg)
                        @._initTaskContent(taskDiv)
                        hs.reset(false)
                    else
                        hs._forceUserHotString('', [])
                        hs.reset('end')
                    @editorTarget$.trigger jQuery.Event('onChange')
                    # to force addhistory on next action
                    @newPosition = true
                    return true

            when 'contact'
                hs._forceUserHotString(autoItem.text, [])
                hs._hsSegment.classList.add('CNE_contact')
                hs._hsSegment.dataset.type = 'contact'
                @Tags._tagList.push(hs._hsSegment) # not clean but perf...
                hs._hsSegment.classList.remove('CNE_hot_string')
                bp = @.insertSpaceAfterSeg(hs._hsSegment)
                @_setCaret(bp.cont,1)
                hs._auto.hide()
                hs._reInit()
                @editorTarget$.trigger jQuery.Event('onChange')
                # to force addhistory on next action
                @newPosition = true
                return true

            when 'htag'
                hs._forceUserHotString(autoItem.text, [])
                hs._hsSegment.classList.add('CNE_htag')
                hs._hsSegment.dataset.type = 'htag'
                @Tags._tagList.push(hs._hsSegment) # not clean but perf...
                hs._hsSegment.classList.remove('CNE_hot_string')
                bp = @.insertSpaceAfterSeg(hs._hsSegment)
                @_setCaret(bp.cont,1)
                hs._auto.hide()
                @editorTarget$.trigger jQuery.Event('onChange')
                # to force addhistory on next action
                @newPosition = true
                return true

            when 'reminder'

                format = (n)->
                    if n.toString().length == 1
                        return '0' + n
                    else
                        return n
                date = autoItem.value
                d    = format(date.getDate()     )
                m    = format(date.getMonth()    )
                y    = format(date.getFullYear() )
                h    = format(date.getHours()    )
                mn   = format(date.getMinutes()  )
                txt  = d + '/' + m + '/' + y + '  ' + h + ':' + mn
                hs._forceUserHotString(txt, [])

                hs._hsSegment.classList.add('CNE_reminder')
                hs._hsSegment.classList.remove('CNE_hot_string')
                hs._hsSegment.dataset.type = 'reminder'
                @Tags._tagList.push(hs._hsSegment) # not clean but perf...
                hs._hsSegment.dataset.value = date.format()

                bp = @.insertSpaceAfterSeg(hs._hsSegment)
                @_setCaret(bp.cont,1)

                hs._auto.hide()
                hs._reInit()
                @editorTarget$.trigger jQuery.Event('onChange')
                # to force addhistory on next action
                @newPosition = true
                return true

        hs.reset('end')
        @editorTarget$.trigger jQuery.Event('onChange')
        return false





    ### ------------------------------------------------------------------------
    # EXTENSION  :  cleaned up HTML parsing
    #
    #  (TODO)
    #
    # We suppose the html treated here has already been sanitized so the DOM
    #  structure is coherent and not twisted
    #
    # _parseHtml:
    #  Parse an html string and return the matching html in the editor's format
    # We try to restitute the very structure the initial fragment :
    #   > indentation
    #   > lists
    #   > images, links, tables... and their specific attributes
    #   > text
    #   > textuals enhancements (bold, underlined, italic)
    #   > titles
    #   > line return
    #
    # Ideas to do that :
    #  0- textContent is always kept
    #  1- A, IMG keep their specific attributes
    #  2- UL, OL become divs whose class is Tu/To. LI become Lu/Lo
    #  3- H[1-6] become divs whose class is Th. Depth is determined depending on
    #     where the element was pasted.
    #  4- U, B have the effect of adding to each elt they contain a class (bold
    #     and underlined class)
    #  5- BR delimit the different DIV that will be added
    #  6- relative indentation preserved with imbrication of paragraphs P
    #  7- any other elt is turned into a simple SPAN with a textContent
    #  8- IFRAME, FRAME, SCRIPT are ignored
    ####

    # _parseHtml : (htmlFrag) ->

        # result = ''

        # specific attributes of IMG and A are copied
        # copySpecificAttributes =
            # "IMG" : (elt) ->
                # attributes = ''
                # for attr in ["alt", "border", "height", "width", "ismap", "hspace", "vspace", "logdesc", "lowsrc", "src", "usemap"]
                    # if attr?
                        # attributes += " #{attr}=#{elt.getAttribute(attr)}"
                # return "<img #{attributes}>#{elt.textContent}</img>"
            # "A" : (elt) ->
                # attributes = ''
                # for attr in ["href", "hreflang", "target", "title"]
                    # if attr?
                        # attributes += " #{attr}=#{elt.getAttribute(attr)}"
                # return "<a #{attributes}>#{elt.textContent}</a>"


        # read recursively through the dom tree and turn the html fragment into
        # a correct bit of html for the editor with the same specific attributes

        # leafReader = (tree) ->
            # if the element is an A or IMG --> produce an editor A or IMG
            # if tree.nodeName == "A" || tree.nodeName == "IMG"
                # return copySpecificAttributes[tree.nodeName](tree)
            # if the element is a BR
            # else if tree.nodeName == "BR"
                # return "<br>"
            # if the element is B, U, I, EM then spread this highlightment
            # if the element is UL(OL) then start a Tu(To)
            # if the element is LI then continue the list (unless if it is the
            #    first child of a UL-OL)
            # else
            # else if tree.firstChild != null
                # sibling = tree.firstChild
                # while sibling != null
                   #  result += leafReader(sibling)
                    # sibling = sibling.nextSibling
            # if the element
                # src = "src=#{tree.getAttribute('src')}"

            # if the element has children
            # child = tree.firstChild
            # if child != null
            #     while child != null
                    # result += leafReader(child)
                    # child = child.nextSibling
            # else

                # return tree.innerHTML || tree.textContent

        # leafReader(htmlFrag)

CNeditor = exports.CNeditor

