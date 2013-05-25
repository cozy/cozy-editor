
# Load librairies used in the app
require '../lib/app_helpers'
CNeditor   = require('CNeditor/editor')
{beautify} = require('views/beautify' )
{AutoTest} = require('views/autoTest' )



###****************************************************
 * 0 - INITIALIZE APP UI
###

$("body").html require './views/templates/editor'
editorIframe$ = $("iframe")

# Use jquery layout to set main layout of current window.
drag = $("#drag")

initialSize = Math.round(window.innerWidth/1.66)

resizeWellEditor = () ->
    edContent = document.getElementById('editorContent')
    editorBtnBar = document.getElementById('editorBtnBar')
    edContent.style.top = editorBtnBar.offsetHeight + 3 + 'px'
    wellEditor = document.getElementById('well-editor')

$("#col-wrap").layout
    east__size: initialSize
    spacing_open: 8
    spacing_closed: 8
    resizable: true
    slidable:false
    togglerLength_closed: "100%"
    onresize_end: ->
        drag.css("z-index","-1")
        resizeWellEditor()

# we detect the start of resize with the on mousedown instead of
# the onresize_start because this one happens a bit latter what may be a pb.
$(".ui-layout-resizer").bind 'mousedown', (e)->
    drag.css("z-index","1")

initialSize2 = Math.round(window.innerWidth/3)


$("#well-result").layout
    west__size: initialSize2
    spacing_open: 8
    spacing_closed: 8
    resizable: true
    slidable:false
    togglerLength_closed: "100%"
    onresize_end: ->
        drag.css("z-index","-1")


###****************************************************
 * 1 - EDITOR CALL BACK
 *
 * callback to execute after editor's initialization
 * the contexte (this) inside the function is the editor
###

# a global var to share the editor to check after a paste event
__editorToCheck = null

cb = () ->

    # editor1 will have a ref to the checker for test puposes
    this.checker = checker

    # During test we want errors not to be intercepted :
    @registerKeyDownCbForTest()

    #### -------------------------------------------------------------------
    # buttons init, beautify actions
    editorCtrler      = this
    editorBody$       = @editorBody$
    recordButton      = $ "#record-button"
    recordPasteButton = $ "#record-paste-button"
    loadHtmlBtn       = $ "#loadHtmlBtn"
    serializerDisplay = $ "#resultText"
    playAllButton     = $ "#play-all-button"
    playRandomButton  = $ "#play-random-button"
    recordList        = $ '#record-list'
    recordSaveButton  = $ '#record-save-button'
    recordSaveInput   = $ '#record-name'
    editor2Btn        = $ '#editor2Btn'
    ed_2_ed2_Btn      = $ '#ed_2_ed2_Btn'
    ed2_2_ed_Btn      = $ '#ed2_2_ed_Btn'
    editorIframe$     = $ '#editorIframe'

    #### -------------------------------------------------------------------
    # buttons for moving editors content from one to the other
    move_ed_2_ed2 = () =>
        parentWidth = editorIframe$.parent().css('width')
        if editorIframe$.css('width') == parentWidth
            editorIframe$.css('width','49%')
        editor2.replaceContent @.linesDiv.innerHTML

    move_ed2_2_ed = () =>
        parentWidth = editorIframe$.parent().css('width')
        if editorIframe$.css('width') == parentWidth
            editorIframe$.css('width','49%')
        @.replaceContent editor2.linesDiv.innerHTML

    editor2Btn.on 'click', () =>
        parentWidth = editorIframe$.parent().css('width')
        if editorIframe$.css('width') != parentWidth
            editorIframe$.css('width','100%')
        else
            editorIframe$.css('width','49%')
            editor2.replaceContent @.linesDiv.innerHTML

    ed_2_ed2_Btn.on 'click', move_ed_2_ed2

    ed2_2_ed_Btn.on 'click', move_ed2_2_ed

    #### -------------------------------------------------------------------
    ### initialize content of the editor
    this.replaceContent( require('views/templates/content-full') )
    this.replaceContent( require('views/templates/content-full-marker') )
    this.replaceContent( require('views/templates/content-shortlines-marker') )
    this.replaceContent( require('views/templates/content-full-relative-indent') )
    this.replaceContent( require('views/templates/content-empty') )
    this.replaceContent( require('views/templates/content-shortlines-all-hacked') )
    content = require('views/templates/test2')
    content = require('views/templates/content-shortlines-medium')
    content = require('views/templates/content-shortlines-large')
    content = require('views/templates/content-for-mad-monkey')
    content = require('views/templates/content-deep-tree')
    content = require('views/templates/content-empty')
    ###
    content = require('views/templates/content-shortlines-small')
    @replaceContent content()
    move_ed_2_ed2()
    # beautify(editorBody$)

    # editorIframe$.css('width','49%')


    #### -------------------------------------------------------------------
    # CHECK SYNTAX
    #
    # > tests the code structure

    checkBtn = $ "#checkBtn"

    _checkEditor = (e) ->
        if e
            target = e.target
            if      target.id == 'editorIframe'
                editor = editor1
            else if target.id == 'editorIframe2'
                editor = editor2
            else if target.id == 'editorDiv3'
                editor = editor3
            checkEditor(editor)
        else
            checkEditor(editor1)
            checkEditor(editor2)
            checkEditor(editor3)

    continuousCheckToggle = () =>
        if not checkBtn.hasClass "btn-warning"
            checkBtn.addClass "btn-warning"
            _checkEditor()
            $('iframe').on("onKeyUp", _checkEditor)
            $('#editorDiv3').on('onKeyUp', _checkEditor)
        else
            checkBtn.removeClass "btn-warning"
            $("iframe").off("onKeyUp", _checkEditor)
            $('#editorDiv3').off("onKeyUp", _checkEditor)

    continuousCheckOn = () ->
        if not checkBtn.hasClass "btn-warning"
            checkBtn.addClass "btn-warning"
            _checkEditor()
            $('#editorDiv3').on("onKeyUp", _checkEditor)
            $("iframe").on("onKeyUp", _checkEditor)

    continuousCheckOff = () ->
        if checkBtn.hasClass "btn-warning"
            checkBtn.removeClass "btn-warning"
            $("iframe").off "onKeyUp", _checkEditor
            $('#editorDiv3').off "onKeyUp", _checkEditor


    continuousCheckOn() # by default activate continuous checking

    checkBtn.click continuousCheckToggle

    #  > translate cozy code into markdown and markdown to cozy code
    #    Note: in the markdown code there should be two \n between each line

    $("#getHtmlBtn").on  'click' , =>
        serializerDisplay.val beautify(@linesDiv.innerHTML)

    $("#getMarkdownBtn").on "click", () ->
        content = editorCtrler.getEditorContent()
        serializerDisplay.val content

    $("#loadMdBtn").on "click", () ->
        editorCtrler.setEditorContent serializerDisplay[0].value
        checkEditor(editorCtrler)

    $("#loadHtmlBtn").on "click", () ->
        # htmlStrg = serializerDisplay[0].value
        # htmlStrg = htmlStrg.replace(/>[\n ]*</g, "><")
        editorCtrler.replaceContent serializerDisplay[0].value,  true
        checkEditor(editorCtrler)

    $("#addClass").toggle(
        () ->
            addClassToLines("sel")
        () ->
            removeClassFromLines("sel")
        )
    #$("#summaryBtn").on "click", () ->
    #    editorCtrler.buildSummary()

    #### -------------------------------------------------------------------
    # Returns an object containing every selected line in the iframe
    getSelectedLines = (sel) ->
        myDivs = []             # Array containing each selected DIV
        if sel.rangeCount == 0
            return
        #_For each selected area
        for i in [0..sel.rangeCount-1]
            range = sel.getRangeAt(i)
            #_Case of multiline selection (includes always at least one div)
            divs = range.getNodes([1], (element) -> element.nodeName=='DIV')
            #_If a single DIV is selected
            if divs.length == 0
                # (bug-counter) the whole body can be "selected"
                if range.commonAncestorContainer.nodeName != 'BODY'
                    node = range.commonAncestorContainer
                    if node.nodeName != 'DIV'
                        node = $(node).parents("div")[0]
                    divs.push node
            # We fill myDivs with the encountered DIV
            k = 0
            while k < divs.length
                myDivs.push $(divs[k])
                k++
        return myDivs


    #### -------------------------------------------------------------------
    # Add class at beginning of lines
    addClassToLines = (mode) =>
        sel = rangy.getIframeSelection(this.editorIframe)
        if mode == "sel"
            lines = getSelectedLines(sel)
            k = 0
            while k < lines.length
                div = lines[k]
                div.attr('toDisplay', div.attr('class') + '] ')
                k++
        else
            lines = this._lines
            for lineID of lines
                div = $ lines[lineID].line$[0]
                div.attr('toDisplay', div.attr('class') + '] ')

    #### -------------------------------------------------------------------
    # Remove class from beginning of lines
    removeClassFromLines = (mode) =>
        sel = rangy.getIframeSelection(this.editorIframe)
        if mode == "sel"
            lines = getSelectedLines(sel)
            k = 0
            while k < lines.length
                div = lines[k]
                div.attr('toDisplay', '')
                k++
        else
            lines = this._lines
            for lineID of lines
                div = $ lines[lineID].line$[0]
                div.attr('toDisplay', '')

    #### -------------------------------------------------------------------
    # (de)activates class auto-display at the beginning of lines
    $("#addClass2LineBtn").on "click", () ->
        addClassToLines()
        if editor_doAddClasseToLines
            $("#addClass2LineBtn").html "Show Class on Lines"
            editor_doAddClasseToLines = false
            editorBody$.off 'keyup' , addClassToLines
            removeClassFromLines()
        else
            $("#addClass2LineBtn").html "Hide Class on Lines"
            editor_doAddClasseToLines = true
            editorBody$.on 'keyup' , addClassToLines

    #### -------------------------------------------------------------------
    # auto check of the syntax after a paste

    # init of the variable referencing the editor to check after a paste event.
    __editorToCheck = null

    editor1.editorBody$.on "paste", () ->
        __editorToCheck = editor1
        window.setTimeout(checkEditor, 400)


    editor2.editorBody$.on "paste", () ->
        __editorToCheck = editor2
        window.setTimeout(checkEditor, 400)

    editor3.editorBody$.on "paste", () ->
        __editorToCheck = editor3
        window.setTimeout(checkEditor, 400)


    #### -------------------------------------------------------------------
    # Recording stuff

    recordStop = () ->
        if recordButton.hasClass "btn-warning"
            recordButton.removeClass "btn-warning"
            recorder.stopRecordSession()

    ###*
     * Load the string in the second editor
     * @param  {string} strg An html or mark down string
     * @param  {boolean} True if strg is html
    ###
    editor2Display = (strg,html) =>
        $('#editorIframe').css('width','49%')
        if html
            editor2.replaceContent strg
            serializerDisplay.val beautify(strg)

        else
            editor2.setEditorContent strg
            serializerDisplay.val strg

    Recorder = require('./views/recorder').Recorder
    recorder = new Recorder(editorCtrler,
                            editorBody$,
                            serializerDisplay,
                            recordList,
                            continuousCheckOff,
                            recordStop,
                            editor2Display)

    recordTest = () ->
        if not recordButton.hasClass "btn-warning"
            recordButton.addClass "btn-warning"
            recorder.startRecordSession()
        else
            recordButton.removeClass "btn-warning"
            recorder.stopRecordSession()

    recordPaste = () ->
        if not recordPasteButton.hasClass "btn-warning"
            recordPasteButton.addClass "btn-warning"
            recorder.startPasteSession()
        else
            recordPasteButton.removeClass "btn-warning"
            recorder.stopPasteSession()

    saveCurrentRecordedTest = () ->
        title = recordSaveInput.val()
        recorder.saveCurrentRecordedTest(title)


    # Recorder buttons

    playAllButton.click ->
        continuousCheckOff()
        recorder.playAll()

    recordButton.click recordTest

    recordPasteButton.click recordPaste

    recordSaveButton.click saveCurrentRecordedTest

    recordSaveInput.on 'keypress', (e) ->
        if e.keyCode == 13
            saveCurrentRecordedTest()

    playRandomButton.click ->
        this.classList.add('btn-warning')
        recorder.launchMadMonkey(5)
        this.classList.remove('btn-warning')

    # Load records
    recorder.load()



###****************************************************
 * 2 - CHECK EDITOR STRUCTURE
###

checker  = new AutoTest()

checkLog = ''

serializerDisplay = $ "#resultText"



checkEditor = (editor) ->
    if !editor
        editor = __editorToCheck
    # console.log 'checkEditor()', editor.editorTarget.id
    res  = checker.checkLines(editor)
    date = new Date()
    h = date.getHours() + ''
    h = if h.length == 1 then '0'+h else h
    m = date.getMinutes() + ''
    m = if m.length == 1 then '0'+m else m
    s = date.getSeconds() + ''
    s = if s.length == 1 then '0'+s else s
    st   = h+":"+m+":"+s+" - "
    switch editor.editorTarget.id
        when 'editorIframe'
            ed = 'editor1'
        when 'editorIframe2'
            ed = 'editor2'
        else
            ed = 'editor3'

    if res
        checkLog += st + 'Syntax test success  (' + ed + ')\n'
        serializerDisplay.val(checkLog)
        $('#well-editor').css('background-color','')
    else
        checkLog += st + ' !!! Syntax test FAILLURE : cf console  !!!   (' + ed + ')\n'
        serializerDisplay.val(checkLog)
        $('#well-editor').css('background-color','#c10000')


###****************************************************
 * Augment editor class with userfull functions
###





doWhenEditorsAreReady = () ->

    # add shortcuts on global objects
    window.ed1 = editor1
    window.ed2 = editor2
    window.ed3 = editor3


    editorCtrler = editor1

    window._history = () ->
        editor1.__printHistory.call(editor1,'editor1')


    $("#ed1").on 'click', () ->
        editorCtrler = editor1
        editorCtrler.setFocus()

    $("#ed2").on 'click', () ->
        editorCtrler = editor2
        editorCtrler.setFocus()

    $("#ed3").on 'click', () ->
        editorCtrler = editor3
        editorCtrler.setFocus()

    $("#printRangeBtn").on "click", () ->
        sel = editorCtrler.getEditorSelection()
        i = 0
        l = sel.rangeCount
        while i < l
            range = sel.getRangeAt(i)
            console.log "------------"
            console.log "  Range N°#{i}"
            console.log range
            printBreakPoint(range.startContainer,range.startOffset, 'start :')
            printBreakPoint(range.endContainer,range.endOffset, 'end   :')
            html = range.cloneContents().innerHTML
            console.log "range.toHtml= #{html}"
            i++
        editorCtrler.setFocus()

    printBreakPoint = (startCont,offset, prefix) ->
        cont = startCont
        res  = []
        while cont.id != "editor-lines" or cont.parentNode == null
            contId = contClass = ''
            if cont.id
                contId = '#' + cont.id
            if cont.className
                contClass = '.'+ cont.className
            # res.unshift(cont.nodeName + contId + contClass)
            res.unshift(cont)
            cont = cont.parentNode
        # console.log prefix , res.join(" / "), '& offset='+offset , startCont
        a = newFilledArray(9-res.length,' ')
        res = res.concat a
        console.log prefix , res[0], res[1], res[2], res[3], res[4], res[5], res[6], res[7], res[8], '& offset='+offset

    newFilledArray = (length, val) ->
        array = []
        for i in [0..length] by 1
            array[i] = val
        return array

    # Allows user to load a file in the Cozy format
    $('#contentSelect').on "change" , (e) ->
        editorCtrler.replaceContent( require("views/templates/#{e.currentTarget.value}")() )
        checkEditor(editorCtrler)

    # Allows user to load a style sheet for the page
    $('#cssSelect').on "change" , (e) ->
        editorCtrler.replaceCSS e.currentTarget.value

    #### -------------------------------------------------------------------
    # Buttons for the editor
    # Buttons should probably give back the focus to the editor's iframe
    $("#indentBtn").on "click", () ->
        editorCtrler.tab()
        editorCtrler.setFocus()

    $("#unIndentBtn").on "click", () ->
        editorCtrler.shiftTab()
        editorCtrler.setFocus()

    $("#markerListBtn").on "click", () ->
        editorCtrler.markerList()
        editorCtrler.setFocus()

    $("#titleBtn").on "click", () ->
        editorCtrler.titleList()
        editorCtrler.setFocus()

    $("#toggleBtn").on "click", () ->
        editorCtrler.toggleType()
        editorCtrler.setFocus()

    $("#strongBtn").on "click", () ->
        editorCtrler.strong()
        editorCtrler.setFocus()

    $("#underlineBtn").on "click", () ->
        editorCtrler.underline()
        editorCtrler.setFocus()

    $("#labelBtn").on "click", () ->
        editorCtrler._applyMetaDataOnSelection('CNE_label')
        editorCtrler.setFocus()

    $("#linkBtn").on "click", () ->
        editorCtrler.linkifySelection()
        editorCtrler.setFocus()

    $("#clearBtn").on "click", () ->
        editorCtrler.deleteContent()
        editorCtrler.setFocus()

    $("#undoBtn").on "click", () ->
        editorCtrler.unDo()
        editorCtrler.setFocus()

    $("#redoBtn").on "click", () ->
        editorCtrler.reDo()
        editorCtrler.setFocus()

    $('#saveBtn').on 'click', () ->
        # editorCtrler.saveTasks()
        editorCtrler.saveTasks()


###****************************************************
 * 3 - CREATION OF THE EDITOR
###
editor1 = 0
editor2 = 0
editor3 = 0

$ ->

    resizeWellEditor()

    $('#ed1').button('toggle')

    editor2 = new CNeditor( document.querySelector('#editorIframe2'), () ->

        @registerKeyDownCbForTest()

        editor1 = new CNeditor document.querySelector('#editorIframe'), cb

        editor3 = new CNeditor( document.querySelector('#editorDiv3'), () ->
            @registerKeyDownCbForTest()
            # content = require('views/templates/content-shortlines-large')
            content = require('views/templates/content-shortlines-small')
            @replaceContent content()
            doWhenEditorsAreReady()
        )

        $('#editorIframe').on 'saveRequest', () ->
            editor1.saveTasks()
        $('#editorIframe2').on 'saveRequest', () ->
            editor2.saveTasks()
        $('#editorDiv3').on 'saveRequest', () ->
            editor3.saveTasks()

    )

