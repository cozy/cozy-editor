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
#   _keyPressListener : (e) =>
#   _insertLineAfter  : (param) ->
#   _insertLineBefore : (param) ->
#   
#   editorIframe      : the iframe element where is nested the editor
#   editorBody$       : the jquery pointer on the body of the iframe
#   _lines            : {} an objet, each property refers a line
#   _highestId        : 
#   _firstLine        : pointes the first line : TODO : not taken into account 
###

class exports.CNeditor

    ###
    #   Constructor : newEditor = new CNEditor( iframeTarget,callBack )
    #       iframeTarget = iframe where the editor will be nested
    #       callBack     = launched when editor ready, the context 
    #                      is set to the editorCtrl (callBack.call(this))
    ###
    constructor : (@editorTarget, callBack) ->
        if @editorTarget.nodeName == "IFRAME"

            # methods to deal selection on an iframe
            @getEditorSelection = () ->
                return rangy.getIframeSelection @editorTarget
            @saveEditorSelection = () ->
                return rangy.saveSelection(rangy.dom.getIframeWindow @editorTarget)
            
            iframe$ = $(@editorTarget)
            
            iframe$.on 'load', () =>

                # 1- preparation of the iframe
                editor_html$ = iframe$.contents().find("html")
                @editorBody$  = editor_html$.find("body")
                @editorBody$.parent().attr('id','__ed-iframe-html')
                @editorBody$.attr("contenteditable", "true")
                @editorBody$.attr("id","__ed-iframe-body")

                @document = @editorBody$[0].ownerDocument
                editor_head$ = editor_html$.find("head")
                editor_head$.html('<link id="editorCSS" href="stylesheets/CNeditor.css" rel="stylesheet">')
            
                # 2- set the properties of the editor
                @_lines       = {}            # contains every line
                @newPosition  = true          # true only if cursor has moved
                @_highestId   = 0             # last inserted line identifier
                @_deepest     = 1             # current maximum indentation
                @_firstLine   = null          # pointer to the first line
                @_history     =               # for history management
                    index        : 0
                    history      : [null]
                    historySelect: [null]
                    historyScroll: [null]
                    historyPos   : [null]
                @_lastKey     = null      # last pressed key (avoid duplication)
                
                # 3- initialize event listeners
                @editorBody$.prop( '__editorCtl', this)
                @editorBody$.on 'mouseup', () =>
                    @newPosition = true
                @editorBody$.on 'keydown', @_keyPressListener
                @editorBody$.on 'keyup', () ->
                    iframe$.trigger jQuery.Event("onKeyUp")
                @editorBody$.on 'click', (event) =>
                    @_lastKey = null
                @editorBody$.on 'paste', (event) =>
                    @paste(e)

                # init clipboard div
                @_initClipBoard()

                # 5- return a ref to the editor's controler
                callBack.call(this)

            # this line is a trick : 
            # the load event is fired on chrome if the iframe src equals '#' but not in ff.
            # and if src= '', it's the opposite : works in ff but not in chrome
            # with this command we force the load on every browser...
            @editorTarget.src = ''


        # if target is not an iframe
        else

            # methods to deal selection on an non-iframe element
            @getEditorSelection = () ->
                return rangy.getSelection()
            @saveEditorSelection = () ->
                return rangy.saveSelection()
                
            node$ = $(@editorTarget)

            # 1- preparation of the editor jframe
            @editorBody$  = node$
            @editorBody$.attr("contenteditable", "true")
            @editorBody$.attr("id","__ed-iframe-body")
        
            # 2- set the properties of the editor
            @_lines       = {}            # contains every line
            @newPosition  = true          # true only if cursor has moved
            @_highestId   = 0             # last inserted line identifier
            @_deepest     = 1             # current maximum indentation
            @_firstLine   = null          # pointer to the first line
            @_history     =               # for history management
                index        : 0
                history      : [null]
                historySelect: [null]
                historyScroll: [null]
                historyPos   : [null]
            @_lastKey     = null      # last pressed key (avoid duplication)
            
            # 3- initialize event listeners
            @editorBody$.prop( '__editorCtl', this)
            #editorBody$.on 'keypress', @_keyPressListener
            @editorBody$.on 'keydown', @_keyPressListener
            @editorBody$.on 'mouseup', () =>
                @newPosition = true
            @editorBody$.on 'keyup', () ->
                node$.trigger jQuery.Event("onKeyUp")
            @editorBody$.on 'click', (event) =>
                @_lastKey = null
            @editorBody$.on 'paste', (event) =>
                @paste(event)

            # init clipboard div
            @_initClipBoard()

            # 4- return a ref to the editor's controler
            callBack.call(this)

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
    _updateDeepest : ->
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
        
    ### ------------------------------------------------------------------------
    # Initialize the editor content from a html string
    ###
    replaceContent : (htmlContent) ->
        @editorBody$.html htmlContent
        @_readHtml()
        @_initClipBoard()
        #@_buildSummary()

    ### ------------------------------------------------------------------------
    # Clear editor content
    ###
    deleteContent : () ->
        @editorBody$.html '<div id="CNID_1" class="Tu-1"><span></span><br></div>'
        @_readHtml()
        @_initClipBoard()
        #@_buildSummary()
    
    ### ------------------------------------------------------------------------
    # Returns a markdown string representing the editor content
    ###
    getEditorContent : () ->
        cozyContent = @editorBody$.html()
        return @_cozy2md cozyContent
        
    ### ------------------------------------------------------------------------
    # Sets the editor content from a markdown string
    ###
    setEditorContent : (mdContent) ->
        cozyContent = @_md2cozy mdContent
        @editorBody$.html cozyContent
        # update the controler
        @_readHtml()
        @_initClipBoard()
                  
    ###
    # Change the path of the css applied to the editor iframe
    ###
    replaceCSS : (path) ->
        # $(this.editorTarget).contents().find("link[rel=stylesheet]").attr({href : path})
        document = @document
        linkElm = document.querySelector('#editorCSS')
        # linkElm = document.createElement('link')
        # linkElm.setAttribute('rel'  , 'stylesheet')
        # linkElm.setAttribute('type' , 'text/css')
        # linkElm.setAttribute('id'   , 'editorCSS')
        linkElm.setAttribute('href' , path)
        document.head.appendChild(linkElm)



    ### ------------------------------------------------------------------------
    # UTILITY FUNCTIONS
    # used to set ranges and help normalize selection
    # 
    # parameters: elt  :  a dom object with only textNode children
    #
    # note: with google chrome, it seems that non visible elements
    #       cannot be selected with rangy (that's where 'blank' comes in)
    ###
    _putEndOnEnd : (range, elt) ->
        if elt.lastChild?
            offset = elt.lastChild.textContent.length
            if offset == 0
                elt.lastChild.data = " "
                offset = 1
            range.setEnd(elt.lastChild, offset)
        else
            blank = document.createTextNode " "
            elt.appendChild blank
            range.setEnd(blank, 1)
            # range.setEnd(elt, 0)
            
    _putStartOnEnd : (range, elt) ->
        if elt.lastChild?
            offset = elt.lastChild.textContent.length
            if offset == 0
                elt.lastChild.data = " "
                offset = 1
            range.setStart(elt.lastChild, offset)
        else
            blank = document.createTextNode " "
            elt.appendChild blank
            range.setStart(blank, 0)
            # range.setStart(elt, 0)
            
    _putEndOnStart : (range, elt) ->
        if elt.firstChild?
            offset = elt.firstChild.textContent.length
            if offset == 0 then elt.firstChild.data = " "
            range.setEnd(elt.firstChild, 0)
        else
            blank = document.createTextNode " "
            elt.appendChild blank
            range.setEnd(blank, 0)
            # range.setEnd(elt, 0)
            
    _putStartOnStart : (range, elt) ->
        if elt.firstChild?
            offset = elt.firstChild.textContent.length
            if offset == 0 then elt.firstChild.data = " "
            range.setStart(elt.firstChild, 0)
        else
            blank = document.createTextNode " "
            elt.appendChild blank
            range.setStart(blank, 0)
            # range.setStart(elt, 0)
            

    ### ------------------------------------------------------------------------
    #  _normalize(range)
    # 
    #  Modify 'range' containers and offsets so it represent a clean selection
    #  that it starts inside a textNode and ends inside a textNode.
    #
    #  Set the flag isEmptyLine to true if an empty line is being normalized
    #  so further suppr ~ backspace work properly.
    #
    # 
    ###
    _normalize : (range) ->

        # Check if the line was empty before normalization
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        if startDiv == endDiv and startDiv.innerHTML == '<span></span><br>'
            @isEmptyLine = true

        
        startContainer = range.startContainer
        # 0. if startC is the body
        if startContainer.nodeName == "BODY"
            elt = startContainer.children[range.startOffset].firstChild
            @_putStartOnStart(range, elt)
        # 1. if startC is a div
        else if startContainer.nodeName == "DIV"
            # 1.1 if line is empty
            if @isEmptyLine
                elt = startContainer.childNodes[0] # span
                @_putStartOnStart(range, elt)
            # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
            else if range.startOffset < startContainer.childNodes.length - 1
                # place caret at the beginning of the next child
                elt = startContainer.childNodes[range.startOffset]
                @_putStartOnStart(range, elt)
            # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
            else
                # place caret at the end of the last child (before br)
                elt = startContainer.lastChild.previousElementSibling
                @_putStartOnEnd(range, elt)
               
        # 2. if startC is a span, a, img
        else if startContainer.nodeName in ["SPAN","IMG","A"]
            # 2.0 if startC is empty
            if startContainer.firstChild == null || startContainer.textContent.length == 0
                @_putStartOnEnd(range, startContainer)
            # 2.1 if caret is between two textNode children
            else if range.startOffset < startContainer.childNodes.length
                # place caret at the beginning of the next child
                targetChild = startContainer.childNodes[range.startOffset]
                range.setStart(targetChild, 0)
            # 2.2 if caret is after last textNode
            else
                # place caret at the end of the last child
                targetChild = startContainer.lastChild
                offset = targetChild.data.length
                range.setStart(targetChild, offset)
                
        # 3. if startC is a textNode ;   do nothing
                
        endContainer = range.endContainer
        # 0. if endC is the body
        if endContainer.nodeName == "BODY"
            elt = endContainer.children[range.endOffset-1].lastChild
            @_putEndOnEnd(range, elt.previousElementSibling)
        # 1. if endC is a div
        if endContainer.nodeName == "DIV"
            # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
            if range.endOffset < endContainer.childNodes.length - 1
                # place caret at the beginning of the next child
                elt = endContainer.childNodes[range.endOffset]
                @_putEndOnStart(range, elt)
            # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
            else
                # place caret at the end of the last child (before br)
                elt = endContainer.lastChild.previousElementSibling
                @_putEndOnEnd(range, elt)
                
        # 2. if endC is a span, a, img
        else if endContainer.nodeName in ["SPAN","IMG","A"]
            # 2.0 if endC is empty
            if endContainer.firstChild==null || endContainer.textContent.length==0
                @_putEndOnEnd(range, endContainer)
            # 2.1 if caret is between two textNode children
            if range.endOffset < endContainer.childNodes.length
                # place caret at the beginning of the next child
                targetChild = startContainer.childNodes[range.endOffset]
                range.setEnd(targetChild, 0)
            # 2.2 if caret is after last textNode
            else
                # place caret at the end of the last child
                targetChild = endContainer.lastChild
                offset = targetChild.data.length
                range.setEnd(targetChild, offset)
        # 3. if endC is a textNode ;   do nothing

        return range



    ### ------------------------------------------------------------------------
    #   _keyPressListener
    # 
    # The listener of keyPress event on the editor's iframe... the king !
    ###
    # 
    # Params :
    # e : the event object. Interesting attributes : 
    #   .which : added by jquery : code of the caracter (not of the key)
    #   .altKey
    #   .ctrlKey
    #   .metaKey
    #   .shiftKey
    #   .keyCode
    ###
    # SHORTCUT
    #
    # Definition of a shortcut : 
    #   a combination alt,ctrl,shift,meta
    #   + one caracter(.which) 
    #   or 
    #     arrow (.keyCode=dghb:) or 
    #     return(keyCode:13) or 
    #     bckspace (which:8) or 
    #     tab(keyCode:9)
    #   ex : shortcut = 'CtrlShift-up', 'Ctrl-115' (ctrl+s), '-115' (s),
    #                   'Ctrl-'
    ###
    # Variables :
    #   metaKeyStrokesCode : ex : ="Alt" or "CtrlAlt" or "CtrlShift" ...
    #   keyStrokesCode     : ex : ="return" or "_102" (when the caracter 
    #                               N°102 f is stroke) or "space" ...
    #
    _keyPressListener : (e) =>
        # 1- Prepare the shortcut corresponding to pressed keys
        # TODO: when pressed key is a letter, prevent the browser default action
        #       and an unDo after a sequence of letters shoud delete it
        metaKeyStrokesCode = `(e.altKey ? "Alt" : "") + 
                              (e.ctrlKey ? "Ctrl" : "") + 
                              (e.shiftKey ? "Shift" : "")`
        switch e.keyCode
            when 13 then keyStrokesCode = "return"
            when 35 then keyStrokesCode = "end"
            when 36 then keyStrokesCode = "home"
            when 33 then keyStrokesCode = "pgUp"
            when 34 then keyStrokesCode = "pgDwn"
            when 37 then keyStrokesCode = "left"
            when 38 then keyStrokesCode = "up"
            when 39 then keyStrokesCode = "right"
            when 40 then keyStrokesCode = "down"
            when 9  then keyStrokesCode = "tab"
            when 8  then keyStrokesCode = "backspace"
            when 32 then keyStrokesCode = "space"
            when 27 then keyStrokesCode = "esc"
            when 46 then keyStrokesCode = "suppr"
            when 16 #Shift
                e.preventDefault()
                return
            when 17 #Ctrl
                e.preventDefault()
                return
            when 18 #Alt
                e.preventDefault()
                return    
            else
                switch e.which # TODO : to be deleted if it works with e.keyCode
                    when 32 then keyStrokesCode = "space"  
                    when 8  then keyStrokesCode = "backspace"
                    when 65 then keyStrokesCode = "A"
                    when 83 then keyStrokesCode = "S"
                    when 86 then keyStrokesCode = "V"
                    when 89 then keyStrokesCode = "Y"
                    when 90 then keyStrokesCode = "Z"
                    #else  keyStrokesCode = e.which
                    else keyStrokesCode = "other"
        shortcut = metaKeyStrokesCode + '-' + keyStrokesCode
        
        # a,s,v,y,z alone are simple characters
        if shortcut in ["-A", "-S", "-V", "-Y", "-Z"] then shortcut = "-other"

        # for tests and check the key and caracter numbers :
        # console.clear()
        # console.log '__keyPressListener____________________________'
        # console.log e
        # console.log "ctrl #{e.ctrlKey}; Alt #{e.altKey}; Shift #{e.shiftKey}; which #{e.which}; keyCode #{e.keyCode}"
        # console.log "metaKeyStrokesCode:'#{metaKeyStrokesCode}' keyStrokesCode:'#{keyStrokesCode}'"
 
        # Record last pressed shortcut and eventually update the history
        if @_lastKey != shortcut and
           shortcut in ["-tab", "-return", "-backspace", "-suppr",
                        "CtrlShift-down", "CtrlShift-up",
                        "CtrlShift-left", "CtrlShift-right",
                        "Ctrl-V", "Shift-tab", "-space", "-other"]
            @_addHistory()
           
        @_lastKey = shortcut


        # 2- manage the newPosition flag
        #    newPosition == true if the position of caret or selection has been
        #    modified with keyboard or mouse.
        #    If newPosition == true and a character is typed or a suppression
        #    key is pressed, then selection must be "normalized" before
        #       - caret must be in a span
        #       - selection must start and end in a span
        # 
        #    Note : in Google Chrome, normalization couldn't place the selection
        #      inside an empty node, so whenever it happens, we create a " "
        #      textNode at this location, then selection is adjusted.
        #      I'm afraid this operation is not that safe.
        
        # If the previous action was a move then "normalize" the selection.
        # Selection is normalized only if an alphanumeric character or
        # suppr/backspace/return is pressed on this new position
        if @newPosition and shortcut in ['-other', '-space',
                                         '-suppr', '-backspace', '-return']
        # if @newPosition
            @newPosition = false
            # get the current range and normalize it
            # (following code is redundant but helpful for debugging)
            sel = @getEditorSelection()
            range = sel.getRangeAt(0)
            normalizedRange = rangy.createRange()
            normalizedRange = @_normalize(range)

            # update window selection so it is normalized
            normalizedSel = @getEditorSelection()
            normalizedSel.setSingleRange(normalizedRange)

        
        # 2.1- Set a flag if the user moved the caret with keyboard
        if keyStrokesCode in ["left","up","right","down",
                              "pgUp","pgDwn","end", "home",
                              "return", "suppr", "backspace"] and
           shortcut not in ["CtrlShift-down", "CtrlShift-up",
                            "CtrlShift-right", "CtrlShift-left"]
            @newPosition = true
        
        # 4- the current selection is initialized on each keypress
        this.currentSel = null
                 
        # 5- launch the action corresponding to the pressed shortcut
        switch shortcut
            # RETURN
            when "-return"
                @_return()
                e.preventDefault()
            # TAB
            when "-tab"
                @tab()
                e.preventDefault()
            when "CtrlShift-right"
                @tab()
                e.preventDefault()
            # BACKSPACE
            when "-backspace"
                @_backspace(e)
            # SUPPR
            when "-suppr"
                @_suppr(e)
            # CTRL SHIFT DOWN
            when "CtrlShift-down"
                @_moveLinesDown()
                e.preventDefault()
            # CTRL SHIFT UP
            when "CtrlShift-up"
                @_moveLinesUp()
                e.preventDefault()
            # SHIFT TAB
            when "Shift-tab"
                @shiftTab()
                e.preventDefault()
            when "CtrlShift-left"
                @shiftTab()
                e.preventDefault()
            # TOGGLE LINE TYPE (Alt + a)                  
            when "Alt-A"
                @_toggleLineType()
                e.preventDefault()
            # PASTE (Ctrl + v)                  
            when "Ctrl-V"
                true
            # SAVE (Ctrl + s)                  
            when "Ctrl-S"
                $(@editorTarget).trigger jQuery.Event("saveRequest")
                e.preventDefault()
            # UNDO (Ctrl + z)
            when "Ctrl-Z"
                e.preventDefault()
                @unDo()
            # REDO (Ctrl + y)
            when "Ctrl-Y"
                e.preventDefault()
                @reDo()
            

    ### ------------------------------------------------------------------------
    #  _suppr :
    # 
    # Manage deletions when suppr key is pressed
    ###
    _suppr : (e) ->
        @_findLinesAndIsStartIsEnd()
        sel = this.currentSel

        if @isEmptyLine
            @isEmptyLine = false
            sel.range.deleteContents()
            
        startLine = sel.startLine
        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed
            # 1.1 caret is at the end of the line
            if sel.rangeIsEndLine
                # if there is a next line : modify the selection to make
                # a multiline deletion
                if startLine.lineNext != null
                    sel.range.setEndBefore(startLine.lineNext.line$[0].firstChild)
                    sel.endLine = startLine.lineNext
                    @_deleteMultiLinesSelections()
                    e.preventDefault()
                # if there is no next line :
                # no modification, just prevent default action
                else
                    e.preventDefault()
            # 1.2 caret is in the middle of the line : nothing to do
            # else

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            sel.range.deleteContents()
            e.preventDefault()

        # 3- Case of a multi lines selection
        else
            @_deleteMultiLinesSelections()
            e.preventDefault()


    ### ------------------------------------------------------------------------
    #  _backspace
    # 
    # Manage deletions when backspace key is pressed
    ###
    _backspace : (e) ->
        @_findLinesAndIsStartIsEnd()

        sel = this.currentSel

        if @isEmptyLine
            @isEmptyLine = false
            sel.range.deleteContents()
                    
        startLine = sel.startLine

        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed
            # 1.1 caret is at the beginning of the line
            if sel.rangeIsStartLine
                # if there is a previous line : modify the selection to make
                # a multiline deletion
                if startLine.linePrev != null
                    sel.range.setStartBefore(startLine.linePrev.line$[0].lastChild)
                    sel.startLine = startLine.linePrev
                    @_deleteMultiLinesSelections()
                    e.preventDefault()
                # if there is no previous line :
                # no modification, just prevent default action
                else
                    e.preventDefault()
            # 1.2 caret is in the middle of the line : nothing to do
            # else

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            sel.range.deleteContents()
            e.preventDefault()

        # 3- Case of a multi lines selection
        else
            @_deleteMultiLinesSelections()
            e.preventDefault()



    ### ------------------------------------------------------------------------
    #  titleList
    # 
    # Turn selected lines in a title List (Th)
    ###
    titleList : () ->
        # 1- Variables
        sel   = @getEditorSelection()
        range = sel.getRangeAt(0)
        
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer

        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        endDivID = endDiv.id
        loop
            @_line2titleList(line)
            if line.lineID == endDivID
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    #  _line2titleList
    # 
    #  Turn a given line in a title List Line (Th)
    ###
    _line2titleList : (line)->
        if line.lineType != 'Th'
            if line.lineType[0] == 'L'
                line.lineType = 'Tu'
                line.lineDepthAbs += 1    
            @_titilizeSiblings(line)
            parent1stSibling = @_findParent1stSibling(line)
            while parent1stSibling!=null and parent1stSibling.lineType != 'Th'
                @_titilizeSiblings(parent1stSibling)
                parent1stSibling = @_findParent1stSibling(parent1stSibling)


    ### ------------------------------------------------------------------------
    # turn in Th or Lh of the siblings of line (and line itself of course)
    # the children are note modified
    ### 
    _titilizeSiblings : (line) ->
        lineDepthAbs = line.lineDepthAbs
        # 1- transform all its next siblings in Th
        l = line
        while l!=null and l.lineDepthAbs >= lineDepthAbs
            if l.lineDepthAbs == lineDepthAbs
                switch l.lineType 
                    when 'Tu','To'
                        l.line$.prop("class","Th-#{lineDepthAbs}")
                        l.lineType = 'Th'
                        l.lineDepthRel = 0
                    when 'Lu','Lo'
                        l.line$.prop("class","Lh-#{lineDepthAbs}")
                        l.lineType = 'Lh'
                        l.lineDepthRel = 0
            l=l.lineNext
        # 2- transform all its previous siblings in Th
        l = line.linePrev 
        while l!=null and l.lineDepthAbs >= lineDepthAbs
            if l.lineDepthAbs == lineDepthAbs
                switch l.lineType
                    when 'Tu','To'
                        l.line$.prop("class","Th-#{lineDepthAbs}")
                        l.lineType = 'Th'
                        l.lineDepthRel = 0
                    when 'Lu','Lo'
                        l.line$.prop("class","Lh-#{lineDepthAbs}")
                        l.lineType = 'Lh'
                        l.lineDepthRel = 0
            l=l.linePrev
        return true


    ### ------------------------------------------------------------------------
    #  markerList
    # 
    #  Turn selected lines in a Marker List
    ###
    markerList : (l) ->
        # 1- Variables
        if l? 
            startDivID = l.lineID
            endLineID  = startDivID
        else
            range = @getEditorSelection().getRangeAt(0)
            if range.startContainer.nodeName == 'BODY'
                startDiv = range.startContainer.children[range.startOffset]
            else
                startDiv = range.startContainer
            if range.endContainer.nodeName == "BODY"
                endDiv = range.endContainer.children[range.endOffset-1]
            else
                endDiv   = range.endContainer
                
            # 2- find first and last div corresponding to the 1rst and
            #    last selected lines
            if startDiv.nodeName != "DIV"
                startDiv = $(startDiv).parents("div")[0]
            startDivID =  startDiv.id
            if endDiv.nodeName != "DIV"
                endDiv = $(endDiv).parents("div")[0]
            endLineID = endDiv.id
            
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDivID]
        loop
            switch line.lineType
                when 'Th'
                    lineTypeTarget = 'Tu'
                    # transform all next Th & Lh siblings in Tu & Lu
                    l = line.lineNext
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        switch l.lineType
                            when 'Th'
                                l.line$.prop("class","Tu-#{l.lineDepthAbs}")
                                l.lineType = 'Tu'
                                l.lineDepthRel = @_findDepthRel(l)
                            when 'Lh'
                                l.line$.prop("class","Lu-#{l.lineDepthAbs}")
                                l.lineType = 'Lu'
                                l.lineDepthRel = @_findDepthRel(l)
                        l=l.lineNext
                    # transform all previous Th &vLh siblings in Tu & Lu
                    l = line.linePrev
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        switch l.lineType
                            when 'Th'
                                l.line$.prop("class","Tu-#{l.lineDepthAbs}")
                                l.lineType = 'Tu'
                                l.lineDepthRel = @_findDepthRel(l)
                            when 'Lh'
                                l.line$.prop("class","Lu-#{l.lineDepthAbs}")
                                l.lineType = 'Lu'
                                l.lineDepthRel = @_findDepthRel(l)
                        l=l.linePrev
                when 'Lh', 'Lu'
                    # remember : the default indentation action is to make 
                    # a marker list, that's why it works here.
                    @tab(line) 
                else
                    lineTypeTarget = false
            # TODO: à supprimer en mettant commençant les boucles par la ligne elle meme et non la suivante
            if lineTypeTarget 
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endLineID
                break
            else 
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


    ### ------------------------------------------------------------------------
    #  _toggleLineType
    # 
    # Toggle line type
    #   usage : cycle : Tu => To => Lx => Th
    #   param :
    #       e = event
    ###
    _toggleLineType : () ->
        # 1- Variables
        sel   = @getEditorSelection()
        range = sel.getRangeAt(0)
        
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer

        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu' # can be turned in a Th only if his parent is a Th
                    lineTypeTarget = 'Th'
                    # transform all its siblings in Th
                    l = line.lineNext 
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Tu'
                                l.line$.prop("class","Th-#{line.lineDepthAbs}")
                                l.lineType = 'Th'
                            else
                                l.line$.prop("class","Lh-#{line.lineDepthAbs}")
                                l.lineType = 'Lh'
                        l=l.lineNext
                    l = line.linePrev 
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Tu'
                                l.line$.prop("class","Th-#{line.lineDepthAbs}")
                                l.lineType = 'Th'
                            else
                                l.line$.prop("class","Lh-#{line.lineDepthAbs}")
                                l.lineType = 'Lh'
                        l=l.linePrev

                when 'Th'
                    lineTypeTarget = 'Tu'
                    # transform all its siblings in Tu
                    l = line.lineNext
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Th'
                                l.line$.prop("class","Tu-#{line.lineDepthAbs}")
                                l.lineType = 'Tu'
                            else
                                l.line$.prop("class","Lu-#{line.lineDepthAbs}")
                                l.lineType = 'Lu'
                        l=l.lineNext
                    l = line.linePrev
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Th'
                                l.line$.prop("class","Tu-#{line.lineDepthAbs}")
                                l.lineType = 'Tu'
                            else
                                l.line$.prop("class","Lu-#{line.lineDepthAbs}")
                                l.lineType = 'Lu'
                        l=l.linePrev
                # when 'Lh'
                #     lineTypeTarget = 'Th'
                # when 'Lu'
                #     lineTypeTarget = 'Tu'
                else
                    lineTypeTarget = false
            if lineTypeTarget 
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endDiv.id
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    #  tab
    # 
    # tab keypress
    #   l = optional : a line to indent. If none, the selection will be indented
    ###
    tab :  (l) ->
        # 1- Variables
        if l? 
            startDiv = l.line$[0]
            endDiv   = startDiv
        else
            sel   = @getEditorSelection()
            range = sel.getRangeAt(0)
            if range.startContainer.nodeName == 'BODY'
                startDiv = range.startContainer.children[range.startOffset]
            else
                startDiv = range.startContainer
            if range.endContainer.nodeName == "BODY"
                endDiv = range.endContainer.children[range.endOffset-1]
            else
                endDiv   = range.endContainer
       
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu','Th'
                    # find previous sibling to check if a tab is possible.
                    linePrevSibling = @_findPrevSibling(line)
                    if linePrevSibling == null
                        isTabAllowed=false
                    else 
                        isTabAllowed=true
                        # determine new lineType
                        if linePrevSibling.lineType == 'Th'
                            lineTypeTarget = 'Lh'
                        else 
                            if linePrevSibling.lineType == 'Tu'
                                lineTypeTarget = 'Lu'
                            else
                                lineTypeTarget = 'Lo'
                            if line.lineType == 'Th'
                                # in case of a Th => Lx then all the following 
                                # siblings must be turned to Tx and Lh into Lx
                                # first we must find the previous sibling line                                
                                # linePrevSibling = @_findPrevSibling(line)
                                # linePrev = line.linePrev
                                # while linePrev.lineDepthAbs > firstChild
                                #     textContent
                                lineNext = line.lineNext
                                while lineNext != null and lineNext.lineDepthAbs > line.lineDepthAbs
                                    switch lineNext.lineType
                                        when 'Th'
                                            lineNext.lineType = 'Tu'
                                            line.line$.prop("class","Tu-#{lineNext.lineDepthAbs}")
                                            nextLineType = prevTxType
                                        when 'Tu'
                                            nextLineType = 'Lu'
                                        when 'To'
                                            nextLineType = 'Lo'
                                        when 'Lh'
                                            lineNext.lineType = nextLineType
                                            line.line$.prop("class","#{nextLineType}-#{lineNext.lineDepthAbs}")
                when 'Lh', 'Lu', 'Lo'
                    # TODO : if there are new siblings, the target type must be 
                    # the one of those, otherwise Tu is default.
                    lineNext = line.lineNext
                    lineTypeTarget = null
                    while lineNext != null and lineNext.lineDepthAbs >= line.lineDepthAbs
                        if lineNext.lineDepthAbs != line.lineDepthAbs + 1
                            lineNext = lineNext.lineNext
                        else
                            lineTypeTarget = lineNext.lineType
                            lineNext=null
                    if lineTypeTarget == null
                        linePrev = line.linePrev
                        while linePrev != null and linePrev.lineDepthAbs >= line.lineDepthAbs
                            if linePrev.lineDepthAbs==line.lineDepthAbs + 1
                                lineTypeTarget = linePrev.lineType
                                linePrev=null
                            else
                                linePrev = linePrev.linePrev
                    if lineTypeTarget == null
                        isTabAllowed       = true
                        lineTypeTarget     = 'Tu'
                        line.lineDepthAbs += 1
                        line.lineDepthRel += 1
                    else
                        if lineTypeTarget == 'Th'
                            isTabAllowed       = true
                            line.lineDepthAbs += 1
                            line.lineDepthRel  = 0
                        if lineTypeTarget == 'Tu' or  lineTypeTarget == 'To'
                            isTabAllowed       = true
                            line.lineDepthAbs += 1
                            line.lineDepthRel += 1
            if isTabAllowed
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endLineID
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    #  shiftTab
    #   param : myRange : if defined, refers to a specific region to untab
    ###
    shiftTab : (myRange) ->

        # 1- Variables
        if myRange?
            range = myRange
        else
            sel   = @getEditorSelection()
            range = sel.getRangeAt(0)
            
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer
        
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        
        # 3- loop on each line between the firts and last line selected
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu','Th','To'
                    # find the closest parent to choose the new lineType.
                    parent = line.linePrev
                    while parent != null and parent.lineDepthAbs >= line.lineDepthAbs
                        parent = parent.linePrev
                    if parent != null
                        isTabAllowed   = true
                        lineTypeTarget = parent.lineType
                        lineTypeTarget = "L" + lineTypeTarget.charAt(1)
                        line.lineDepthAbs -= 1
                        line.lineDepthRel -= parent.lineDepthRel
                        # if lineNext is a Lx, then it must be turned in a Tx
                        if line.lineNext? and line.lineNext.lineType[0]=='L'
                            nextL = line.lineNext
                            nextL.lineType='T'+nextL.lineType[1] 
                            nextL.line$.prop('class',"#{nextL.lineType}-#{nextL.lineDepthAbs}")
                    else 
                        isTabAllowed = false
                when 'Lh'
                    isTabAllowed=true
                    lineTypeTarget     = 'Th'
                when 'Lu'
                    isTabAllowed=true
                    lineTypeTarget     = 'Tu'
                when 'Lo'
                    isTabAllowed=true
                    lineTypeTarget     = 'To'
            if isTabAllowed
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endDiv.id
                break
            else 
                line = line.lineNext

    ### ------------------------------------------------------------------------
    #  _return
    # return keypress
    #   e = event
    ###
    _return : () ->
        @_findLinesAndIsStartIsEnd()
        currSel   = this.currentSel
        startLine = currSel.startLine
        endLine   = currSel.endLine

        # 1- Delete the selections so that the selection is collapsed
        if currSel.range.collapsed
            
        else if endLine == startLine
            currSel.range.deleteContents()
        else
            @_deleteMultiLinesSelections()
            @_findLinesAndIsStartIsEnd()
            currSel   = this.currentSel
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
            range4sel = rangy.createRange()
            range4sel.collapseToPoint(newLine.line$[0].firstChild,0)
            currSel.sel.setSingleRange(range4sel)

        # 3- Caret is at the beginning of the line
        else if currSel.rangeIsStartLine
            newLine = @_insertLineBefore (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
            )
            # Position caret
            range4sel = rangy.createRange()
            range4sel.collapseToPoint(startLine.line$[0].firstChild,0)
            currSel.sel.setSingleRange(range4sel)

        # 4- Caret is in the middle of the line
        else                     
            # Deletion of the end of the original line
            currSel.range.setEndBefore( startLine.line$[0].lastChild )
            endOfLineFragment = currSel.range.extractContents()
            currSel.range.deleteContents()
            # insertion
            newLine = @_insertLineAfter (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
                fragment           : endOfLineFragment
            )
            # Position caret
            range4sel = rangy.createRange()
            #range4sel.collapseToPoint(newLine.line$[0].firstChild.childNodes[0],0)
            range4sel.collapseToPoint(newLine.line$[0].firstChild,0)
            
            currSel.sel.setSingleRange(range4sel)
            this.currentSel = null



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
            while linePrev != null and linePrev.lineDepthAbs > (lineDepthAbs - 2)
                linePrev = linePrev.linePrev
            return linePrev.lineNext


    ### ------------------------------------------------------------------------
    #  _findPrevSibling
    # 
    # find the previous sibling line.
    # returns null if no previous sibling, the line otherwise
    # the sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
    ###
    _findPrevSibling : (line)->
        lineDepthAbs = line.lineDepthAbs
        linePrevSibling = line.linePrev
        if linePrevSibling == null
            # nothing to do if first line
            return null
        else if linePrevSibling.lineDepthAbs < lineDepthAbs
            # If AbsDepth of previous line is lower : we are on the first
            # line of a list of paragraphes, there is no previous sibling
            return null
        else
            while linePrevSibling.lineDepthAbs > lineDepthAbs
                linePrevSibling = linePrevSibling.linePrev
            while linePrevSibling.lineType[0] == 'L'
                linePrevSibling = linePrevSibling.linePrev
            return linePrevSibling


    ### ------------------------------------------------------------------------
    #  _deleteMultiLinesSelections
    # 
    # Delete the user multi line selection
    #
    # prerequisite : at least 2 different lines must be selected
    # parameters   : startLine = first line to be deleted
    #                endLine   = last line to be deleted
    ###
    _deleteMultiLinesSelections : (startLine, endLine) ->
        # If startLine and endLine are specified, lines included between these
        # two are removed. This is useful when making line's depth inheritance
        
        # true when the caret needs to be repositioned after deletion
        replaceCaret = true

        # 0 - variables
        if startLine != undefined
            replaceCaret = false
            range = rangy.createRange()
            
            # If the very first line must be deleted
            if startLine == null
                startLine = endLine
                endLine = endLine.lineNext
                @_putStartOnStart(range, startLine.line$[0].firstElementChild)
                endLine.line$.prepend '<span></span>'
                @_putEndOnStart(range, endLine.line$[0].firstElementChild)
            else
                startNode = startLine.line$[0].lastElementChild.previousElementSibling
                endNode = endLine.line$[0].lastElementChild.previousElementSibling
                range.setStartAfter(startNode,0)
                range.setEndAfter(endNode,0)
        else
            @_findLines()
            range = this.currentSel.range
            startContainer = range.startContainer
            startOffset    = range.startOffset
            startLine      = this.currentSel.startLine
            endLine        = this.currentSel.endLine
            
        endLineDepthAbs   = endLine.lineDepthAbs
        startLineDepthAbs = startLine.lineDepthAbs
        deltaDepth        = endLineDepthAbs - startLineDepthAbs

        # 1- copy the end of endLine in a fragment
        range4fragment = rangy.createRangyRange()
        range4fragment.setStart(range.endContainer, range.endOffset)
        range4fragment.setEndAfter(endLine.line$[0].lastChild)
        endOfLineFragment = range4fragment.cloneContents()

        # 2- adapt the type of endLine and of its children to startLine 
        # the only useful case is when endLine must be changed from Th to Tu or To
        if endLine.lineType[1] == 'h' and startLine.lineType[1] != 'h'
            if endLine.lineType[0] == 'L'
                endLine.lineType = 'T' + endLine.lineType[1]
                endLine.line$.prop("class","#{endLine.lineType}-#{endLine.lineDepthAbs}")
            @markerList(endLine)

        # 3- delete lines
        range.deleteContents()

        # 4- append fragment and delete endLine
        # TODO : consider using _insertFrag 
        if startLine.line$[0].lastChild.nodeName == 'BR'
            startLine.line$[0].removeChild( startLine.line$[0].lastChild)
        startFrag = endOfLineFragment.childNodes[0]
        myEndLine = startLine.line$[0].lastElementChild
        # if startFrag et myEndLine are SPAN and they both have the same class
        # then we concatenate both
        if startFrag.tagName == myEndLine.tagName == 'SPAN' and
           startFrag.className == myEndLine.className             
            startOffset = myEndLine.textContent.length
            newText = myEndLine.textContent + startFrag.textContent
            myEndLine.innerHTML = newText
            startContainer = myEndLine.firstChild
            
            l=1
            while l < endOfLineFragment.childNodes.length
                $(endOfLineFragment.childNodes[l]).appendTo startLine.line$
                l++
        else
            startLine.line$.append( endOfLineFragment )
            
        startLine.lineNext = endLine.lineNext
        if endLine.lineNext != null
            endLine.lineNext.linePrev=startLine
        endLine.line$.remove()
        delete this._lines[endLine.lineID]

        # 5- adapt the depth of the children and following siblings of end line
        #    in case the depth delta between start and end line is
        #    greater than 0, then the structure is not correct : we reduce
        #    the depth of all the children and siblings of endLine.
        line = startLine.lineNext
        if line != null
            deltaDepth1stLine = line.lineDepthAbs - startLineDepthAbs
            if deltaDepth1stLine >= 1 
                while line!= null and line.lineDepthAbs >= endLineDepthAbs
                    newDepth = line.lineDepthAbs - deltaDepth
                    line.lineDepthAbs = newDepth
                    line.line$.prop("class","#{line.lineType}-#{newDepth}")
                    line = line.lineNext
                    
        # 6- adapt the type of the first line after the children and siblings of
        #    end line. Its previous sibling or parent might have been deleted, 
        #    we then must find its new one in order to adapt its type.
        if line != null
            # if the line is a line (Lx), then make it "independant"
            # by turning it in a Tx
            if line.lineType[0] == 'L'
                line.lineType = 'T' + line.lineType[1]
                line.line$.prop("class","#{line.lineType}-#{line.lineDepthAbs}")
            # find the previous sibling, adjust type to its type.
            firstLineAfterSiblingsOfDeleted = line
            depthSibling = line.lineDepthAbs
            
            line = line.linePrev
            while line != null and line.lineDepthAbs > depthSibling
                line = line.linePrev
            if line != null
                prevSiblingType = line.lineType
                if firstLineAfterSiblingsOfDeleted.lineType!=prevSiblingType
                    if prevSiblingType[1]=='h'
                        @_line2titleList(firstLineAfterSiblingsOfDeleted)
                    else
                        @markerList(firstLineAfterSiblingsOfDeleted)

        # 7- position caret
        if replaceCaret
            range4caret = rangy.createRange()
            range4caret.collapseToPoint(startContainer, startOffset)
            this.currentSel.sel.setSingleRange(range4caret)
            this.currentSel = null
        # else
        #   do nothing
        
                
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
    #     innerHTML          : [optionnal] - an html string that will be added
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineAfter : (p) ->
        @_highestId += 1
        lineID          = 'CNID_' + @_highestId
        if p.fragment?
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
            newLine$.append( p.fragment )
            if newLine$[0].childNodes.length == 0 or newLine$[0].lastChild.nodeName != 'BR'
                newLine$.append('<br>')
        else if p.innerHTML?
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'>
                #{p.innerHTML}</div>")
            if newLine$[0].lastChild.nodeName != 'BR'
                newLine$.append('<br>')
        else
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
            newLine$.append( $('<span></span><br>') )
        sourceLine = p.sourceLine
        newLine$   = newLine$.insertAfter(sourceLine.line$)
        newLine    =
            line$        : newLine$
            lineID       : lineID
            lineType     : p.targetLineType
            lineDepthAbs : p.targetLineDepthAbs
            lineDepthRel : p.targetLineDepthRel
            lineNext     : sourceLine.lineNext
            linePrev     : sourceLine
        @_lines[lineID] = newLine
        if sourceLine.lineNext != null
            sourceLine.lineNext.linePrev = newLine
        sourceLine.lineNext = newLine
        return newLine



    ### ------------------------------------------------------------------------
    #  _insertLineBefore
    # 
    # Insert a line before a source line
    # p = 
    #     sourceLine         : ID of the line before which a line will be added
    #     fragment           : [optionnal] - an html fragment that will be added
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineBefore : (p) ->
        @_highestId += 1
        lineID = 'CNID_' + @_highestId
        newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
        if p.fragment? 
            newLine$.append( p.fragment )
            newLine$.append( $('<br>') )
        else
            newLine$.append( $('<span></span><br>') )
        sourceLine = p.sourceLine
        newLine$ = newLine$.insertBefore(sourceLine.line$)
        newLine = 
            line$        : newLine$
            lineID       : lineID
            lineType     : p.targetLineType
            lineDepthAbs : p.targetLineDepthAbs
            lineDepthRel : p.targetLineDepthRel
            lineNext     : sourceLine
            linePrev     : sourceLine.linePrev
        @_lines[lineID] = newLine
        if sourceLine.linePrev != null
            sourceLine.linePrev.lineNext = newLine
        sourceLine.linePrev=newLine
        return newLine


    ### ------------------------------------------------------------------------
    #  _findLines
    #  
    # Finds :
    #   First and last line of selection. 
    # Remark :
    #   Only the first range of the selections is taken into account.
    # Returns : 
    #   sel : the selection
    #   range : the 1st range of the selections
    #   startLine : the 1st line of the range
    #   endLine : the last line of the range
    ###
    _findLines : () ->
        if this.currentSel == null
            # 1- Variables
            sel                = @getEditorSelection()
            range              = sel.getRangeAt(0)
            startContainer     = range.startContainer
            endContainer       = range.endContainer
            initialStartOffset = range.startOffset
            initialEndOffset   = range.endOffset
            
            # 2- find endLine 
            # endContainer refers to a div of a line
            if endContainer.id? and endContainer.id.substr(0,5) == 'CNID_'  
                endLine = @_lines[ endContainer.id ]
            # means the range ends inside a div (span, textNode...)
            else   
                endLine = @_lines[ $(endContainer).parents("div")[0].id ]
            
            # 3- find startLine
            if startContainer.nodeName == 'DIV'
                # startContainer refers to a div of a line
                startLine = @_lines[ startContainer.id ]
            else   # means the range starts inside a div (span, textNode...)
                startLine = @_lines[ $(startContainer).parents("div")[0].id ]
            
            # 4- return
            return this.currentSel = 
                sel              : sel
                range            : range
                startLine        : startLine
                endLine          : endLine
                rangeIsStartLine : null
                rangeIsEndLine   : null


    ### ------------------------------------------------------------------------
    #  _findLinesAndIsStartIsEnd
    # 
    # Finds :
    #   first and last line of selection 
    #   wheter the selection starts at the beginning of startLine or not
    #   wheter the selection ends at the end of endLine or not
    # 
    # Remark :
    #   Only the first range of the selections is taken into account.
    #
    # Returns : 
    #   sel   : the selection
    #   range : the 1st range of the selections
    #   startLine : the 1st line of the range
    #   endLine   : the last line of the range
    #   rangeIsEndLine   : true if the range ends at the end of the last line
    #   rangeIsStartLine : true if the range starts at the start of 1st line
    ###
    _findLinesAndIsStartIsEnd : () ->
        if this.currentSel == null
            
            # 1- Variables
            sel                = @getEditorSelection()
            range              = sel.getRangeAt(0)
            startContainer     = range.startContainer
            endContainer       = range.endContainer
            initialStartOffset = range.startOffset
            initialEndOffset   = range.endOffset

            # 2- find endLine and the rangeIsEndLine
            # endContainer refers to a div of a line
            if endContainer.id? and endContainer.id.substr(0,5) == 'CNID_'
                endLine = @_lines[ endContainer.id ]
                # rangeIsEndLine if endOffset points on the last node of the div
                # or on the one before the last which is a <br>
                rangeIsEndLine = endContainer.children.length < initialEndOffset or endContainer.children[initialEndOffset].nodeName=="BR"
            # means the range ends inside a div (span, textNode...)
            else
                endLine = @_lines[ $(endContainer).parents("div")[0].id ]
                # rangeIsEndLine if the selection is at the end of the
                # endContainer and of each of its parents (this approach is more
                # robust than just considering that the line is a flat
                # succession of span : maybe one day there will be a table for
                # instance...)
                rangeIsEndLine = false
                # case of a textNode: it must have no nextSibling
                # and offset must be its length
                if endContainer.nodeType == Node.TEXT_NODE
                    rangeIsEndLine = endContainer.nextSibling == null and
                                     initialEndOffset == endContainer.textContent.length
                # case of another node : it must be a br;
                # or be followed by a br and have maximal offset.
                else
                    rangeIsEndLine = endContainer.nodeName=='BR' or
                                     (endContainer.nextSibling.nodeName=='BR' and
                                     endContainer.childNodes.length==initialEndOffset)
                    #nextSibling    = endContainer.nextSibling
                    #rangeIsEndLine = (nextSibling == null or nextSibling.nodeName=='BR')
                    #(nextSibling == null or (initialEndOffset==parentEndContainer.textContent.length and nextSibling.nodeName=='BR'))
                    
                parentEndContainer = endContainer.parentNode
                while rangeIsEndLine and parentEndContainer.nodeName != "DIV"
                    nextSibling = parentEndContainer.nextSibling
                    rangeIsEndLine = (nextSibling == null or nextSibling.nodeName=='BR')
                    # rangeIsEndLine = endContainer.nodeName=='BR' or
                    #                  (nextSibling.nodeName=='BR' and
                    #                  endContainer.childNodes.length==initialEndOffset)
                    parentEndContainer = parentEndContainer.parentNode
            
            # 3- find startLine and rangeIsStartLine
            if startContainer.nodeName == 'DIV' # startContainer refers to a div of a line
                startLine = @_lines[ startContainer.id ]
                rangeIsStartLine = initialStartOffset == 0
                
            else   # means the range starts inside a div (span, textNode...)
            
                startLine = @_lines[ $(startContainer).parents("div")[0].id ]
                # case of a textNode: it must have no previousSibling nor offset
                if startContainer.nodeType == Node.TEXT_NODE
                    rangeIsStartLine = endContainer.previousSibling == null and
                                       initialStartOffset == 0
                else
                    rangeIsStartLine = initialStartOffset == 0
                
                parentStartContainer = startContainer.parentNode
                while rangeIsStartLine && parentStartContainer.nodeName != "DIV"
                    rangeIsStartLine = parentStartContainer.previousSibling == null
                    parentStartContainer = parentStartContainer.parentNode

            # Special case of an "empty" line (<span><""></span><br>)
            if endLine.line$[0].innerHTML == "<span></span><br>"
                rangeIsEndLine = true
            if startLine.line$[0].innerHTML == "<span></span><br>"
                rangeIsStartLine = true

            # 4- return
            return this.currentSel = 
                sel              : sel
                range            : range
                startLine        : startLine
                endLine          : endLine
                rangeIsStartLine : rangeIsStartLine
                rangeIsEndLine   : rangeIsEndLine
        # return [sel,range,endLine,rangeIsEndLine,startLine,rangeIsStartLine]



    ###  -----------------------------------------------------------------------
    #   _readHtml
    # 
    # Parse a raw html inserted in the iframe in order to update the controller
    ###
    _readHtml : () ->
        linesDiv$    = @editorBody$.children()  # linesDiv$= $[Div of lines]
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
                DeltaDepthAbs    = lineDepthAbs - lineDepthAbs_old
                lineDepthRel_old = lineDepthRel
                if lineType == "Th"
                    lineDepthRel = 0
                else
                    lineDepthRel = lineDepthRel_old + DeltaDepthAbs
                lineID=(parseInt(lineID,10)+1)
                lineID_st = "CNID_"+lineID
                htmlLine$.prop("id",lineID_st)
                lineNew =
                    line$        : htmlLine$
                    lineID       : lineID_st
                    lineType     : lineType
                    lineDepthAbs : lineDepthAbs
                    lineDepthRel : lineDepthRel
                    lineNext     : null
                    linePrev     : linePrev
                if linePrev != null then linePrev.lineNext = lineNew
                linePrev = lineNew
                @_lines[lineID_st] = lineNew
        @_highestId = lineID



    ### ------------------------------------------------------------------------
    # LINES MOTION MANAGEMENT
    # 
    # Functions to perform the motion of an entire block of lines
    # BUG : when doubleclicking on an end of line then moving this line
    #       down, selection does not behaves as expected :-)
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
        
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer

        # Find first and last div corresponding to the first and last
        # selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        startLineID = startDiv.id
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        
        lineStart = @_lines[startLineID]
        lineEnd   = @_lines[endLineID]
        linePrev  = lineStart.linePrev
        lineNext  = lineEnd.lineNext
            
        # if the last selected line (lineEnd) isnt the very last line
        if lineNext != null
            
            # 1 - save lineNext
            cloneLine =
                line$        : lineNext.line$.clone()
                lineID       : lineNext.lineID
                lineType     : lineNext.lineType
                lineDepthAbs : lineNext.lineDepthAbs
                lineDepthRel : lineNext.lineDepthRel
                linePrev     : lineNext.linePrev
                lineNext     : lineNext.lineNext

            # savedSel = @saveEditorSelection()
                
            # 2 - Delete lineNext content then restore initial selection
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
                myRange = rangy.createRange()
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
                myRange = rangy.createRange()
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
        
        if range.startContainer.nodeName == 'BODY'
            startDiv = range.startContainer.children[range.startOffset]
        else
            startDiv = range.startContainer
        if range.endContainer.nodeName == "BODY"
            endDiv = range.endContainer.children[range.endOffset-1]
        else
            endDiv   = range.endContainer

        # Find first and last div corresponding to the first and last
        # selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        startLineID = startDiv.id
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
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
            cloneLine =
                line$        : linePrev.line$.clone()
                lineID       : linePrev.lineID
                lineType     : linePrev.lineType
                lineDepthAbs : linePrev.lineDepthAbs
                lineDepthRel : linePrev.lineDepthRel
                linePrev     : linePrev.linePrev
                lineNext     : linePrev.lineNext

            # savedSel = @saveEditorSelection()
            
            # 2 - Delete linePrev content then restore initial selection
            @_deleteMultiLinesSelections(linePrev.linePrev, linePrev)
            
            # rangy.restoreSelection(savedSel)

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
                #                    to last  line to untab (line)
                myRange = rangy.createRange()
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
                myRange = rangy.createRange()
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


    ### ------------------------------------------------------------------------
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

    ### -------------------------------------------------------------------------
    #  _addHistory
    # 
    # Add html code and selection markers and scrollbar positions to the history
    ###
    _addHistory : () ->
        # 0 - mark selection
        savedSel = @saveEditorSelection()
        # save html selection
        @_history.historySelect.push savedSel
        # save scrollbar position
        savedScroll = 
            xcoord: @editorBody$.scrollTop()
            ycoord: @editorBody$.scrollLeft()
        @_history.historyScroll.push savedScroll
        # save newPosition
        @_history.historyPos.push @newPosition
        # 1- add the html content with markers to the history
        @_history.history.push @editorBody$.html()
        rangy.removeMarkers(savedSel)
        # 2 - update the index
        @_history.index = @_history.history.length-1

    ### -------------------------------------------------------------------------
    #  undoPossible
    # Return true only if unDo can be called
    ###
    undoPossible : () ->
        return (@_history.index > 0)

    ### -------------------------------------------------------------------------
    #  redoPossible
    # Return true only if reDo can be called
    ###
    redoPossible : () ->
        return (@_history.index < @_history.history.length-2)

    ### -------------------------------------------------------------------------
    #  unDo :
    # Undo the previous action
    ###
    unDo : () ->
        # if there is an action to undo
        if @undoPossible()
            # if we are in an unsaved state
            if @_history.index == @_history.history.length-1
                # save current state
                @_addHistory()
                # re-evaluate index
                @_history.index -= 1

            # restore newPosition
            @newPosition = @_history.historyPos[@_history.index]
            # 0 - restore html
            @editorBody$.html @_history.history[@_history.index]
            # 1 - restore selection
            savedSel = @_history.historySelect[@_history.index]
            savedSel.restored = false
            rangy.restoreSelection(savedSel)
            # 2 - restore scrollbar position
            xcoord = @_history.historyScroll[@_history.index].xcoord
            ycoord = @_history.historyScroll[@_history.index].ycoord
            @editorBody$.scrollTop(xcoord)
            @editorBody$.scrollLeft(ycoord)
            # 3 - restore the lines structure
            @_readHtml()
            # 4 - update the index
            @_history.index -= 1

    ### -------------------------------------------------------------------------
    #  reDo :
    # Redo a undo-ed action
    ###
    reDo : () ->
        # if there is an action to redo
        if @redoPossible()
            # restore newPosition
            @newPosition = @_history.historyPos[@_history.index+1]
            # 0 - update the index
            @_history.index += 1
            # 1 - restore html
            @editorBody$.html @_history.history[@_history.index+1]
            # 2 - restore selection
            savedSel = @_history.historySelect[@_history.index+1]
            savedSel.restored = false
            rangy.restoreSelection(savedSel)
            # 3 - restore scrollbar position
            xcoord = @_history.historyScroll[@_history.index+1].xcoord
            ycoord = @_history.historyScroll[@_history.index+1].ycoord
            @editorBody$.scrollTop(xcoord)
            @editorBody$.scrollLeft(ycoord)
            # 4 - restore lines structure
            @_readHtml()


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
            if (@editorBody$.children("#" + "#{lines[c].lineID}").length > 0 and lines[c].lineType == "Th")
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
        @_findLinesAndIsStartIsEnd()
        # move caret into the sandbox
        range = rangy.createRange()
        range.selectNodeContents mySandBox
        sel = @getEditorSelection()
        sel.setSingleRange range
        range.detach()
        # check whether the browser is a Webkit or not
        console.log "event :"
        console.log event
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
            mySandBox.innerHTML = ""
            @_waitForPasteData mySandBox
            return true



    ###*
     * init the div where the browser will actualy paste.
     * this method is called after each refresh of the content of the editor (
     * replaceContent, deleteContent, setEditorContent)
     * TODO : should be called just once at editor init : for this the editable
     * content shouldn't be directly in the body of the iframe but in a div.
     * @return {obj} a ref to the clipboard div
    ###
    _initClipBoard : () ->
        clipboard$ = $ document.createElement('div')
        getOffTheScreen =
            left: -300
        clipboard$.offset getOffTheScreen
        clipboard$.prependTo @editorBody$
        @clipboard = clipboard$[0]
        @clipboard.style.setProperty('width','280px')
        @clipboard.style.setProperty('position','fixed')
        @clipboard.style.setProperty('overflow','hidden')
        @clipboard
    


    ###*
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
            setTimeout @_waitForPasteData, 10
       


    ###
     * Called when the browser has pasted data in the clipboard div. Its role is to
     * insert the content of the clipboard into the editor.
     * @param  {element} sandbox 
    ###

    _processPaste : () =>
        # var
        console.log "process paste"
        
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
        # inserted in frag.
        # _domWalk is recursive and the variables of the context of the parse 
        # are stored in the parameter "domWalkContext" that is transmited at
        # each recursion.
        currentLineFrag = document.createDocumentFragment()
        absDepth = currSel.startLine.lineDepthAbs
        if currSel.startLine.lineType == 'Th'
            absDepth += 1
        domWalkContext =
            # Absolute depth of the current explored node.
            absDepth           : absDepth,
            # level of the Previous  <hx> element (ex : if last title parsed 
            # was h3 => prevHxLevel==)
            prevHxLevel        : null,
            # the fragment where new lines will be added during the parse of the
            # clipboard div
            frag               : frag,
            # previous Cozy Note Line Abs Depth, used for the insertion of 
            # internal lines with  _clipBoard_Insert_InternalLine()
            prevCNLineAbsDepth : null,
            # refers to the record of editor.lines[] of the last inserted 
            # line in the frag
            lastAddedLine      : dummyLine,
            # Fragment where a line is under construction
            currentLineFrag    : currentLineFrag,
            # last element of currentLineFrag being populated by _domWalk
            currentLineEl      : currentLineFrag,
            # boolean indicating wether currentLineFrag has already be appended
            # an element.
            isCurrentLineBeingPopulated : false

        # go for the walk !
        htmlStr = @_domWalk sandbox, domWalkContext
        
        # empty the clipboard div
        sandbox.innerHTML = ""
        # delete dummy line from the fragment
        frag.removeChild(frag.firstChild)
        console.log frag
        

        ###
        # TODO : the following steps removes all the styles of the lines in frag
        # Later this will be removed in order to take into account styles.
        ###
        i = 0
        while i<frag.childNodes.length
            line = frag.childNodes[i]
            txt = line.textContent
            line.innerHTML = '<span></span><br>'
            line.firstChild.appendChild(document.createTextNode(txt))
            i += 1
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
        else
            @_deleteMultiLinesSelections()
            currSel   = @_findLinesAndIsStartIsEnd()
            startLine = currSel.startLine

        # 5- insert first line of the frag in the target line
        # we assume that the structure of lines in frag and in the editor are :
        # <div><span>(TextNode)</span><br></div>
        # what is incorrect when styles will be taken into account.
        targetNode   = currSel.range.startContainer
        startOffset  = currSel.range.startOffset
        if targetNode.length
            endOffset = targetNode.length - startOffset
        else
            endOffset = targetNode.childNodes.length - startOffset
        i=0
        lineElements = frag.firstChild.childNodes
        nbElements   = lineElements.length
        while i < nbElements-1
            elToInsert = lineElements[i]
            i += 1
            # if targetNode & elToInsert are SPAN or TextNode and both have 
            # the same class, then we concatenate them
            if (elToInsert.tagName=='SPAN') and
            (targetNode.tagName=='SPAN' or targetNode.nodeType==Node.TEXT_NODE )
                targetText   = targetNode.textContent
                newText      = targetText.substr(0,startOffset)
                newText     += elToInsert.textContent
                newText     += targetText.substr(startOffset)
                targetNode.textContent = newText
                startOffset += elToInsert.textContent.length

        # 6- if the clipboard has more than one line, insert the end of target
        #    line in the last line of frag and delete it
        if frag.childNodes.length > 1
            range = document.createRange()
            range.setStart(targetNode,startOffset)
            parendDiv = targetNode
            while parendDiv.tagName != 'DIV'
                parendDiv = parendDiv.parentElement
            range.setEnd(parendDiv,parendDiv.children.length-1)
            endTargetLineFrag = range.extractContents()
            range.detach()
            this._insertFrag(
                frag.lastChild,                    # last line of frag
                frag.lastChild.children.length-1,  # penultimate node of last line
                endTargetLineFrag)                 # the frag to insert
            # TODO : the next 3 lines are required for firebug to detect
            # breakpoints ! ! !   ????????
            parendDiv = targetNode
            while parendDiv.tagName != 'DIV'
                parendDiv = parendDiv.parentElement

        # remove the firstAddedLine from the fragment
        firstAddedLine = dummyLine.lineNext
        secondAddedLine = firstAddedLine.lineNext
        frag.removeChild(frag.firstChild)
        delete this._lines[firstAddedLine.lineID]

        # 7- updates nextLine and prevLines, insert frag in the editor
        if secondAddedLine != null
            lineNextStartLine          = currSel.startLine.lineNext
            currSel.startLine.lineNext = secondAddedLine
            secondAddedLine.linePrev   = currSel.startLine
            if lineNextStartLine == null
                @editorBody$[0].appendChild(frag)
            else
                domWalkContext.lastAddedLine.lineNext = lineNextStartLine
                lineNextStartLine.linePrev = domWalkContext.lastAddedLine
                @editorBody$[0].insertBefore(frag, lineNextStartLine.line$[0])
        
        # 8- position caret
        if secondAddedLine != null
            # Assumption : last inserted line always has at least one <span> with only text inside
            caretTextNodeTarget = lineNextStartLine.linePrev.line$[0].childNodes[0].firstChild
            caretOffset = caretTextNodeTarget.length - endOffset
            currSel.sel.collapse(caretTextNodeTarget, caretOffset)
        else
            currSel.sel.collapse(targetNode, startOffset)



    ###*
     * Insert a frag in a node container at startOffset
     * ASSERTION : 
     * TODO : this method could be also used in _deleteMultiLinesSelections 
     * especialy if _insertFrag optimizes the insertion by fusionning cleverly
     * the elements
     * @param  {Node} targetContainer the node where to make the insert
     * @param  {Integer} targetOffset    the offset of insertion in targetContainer
     * @param  {fragment} frag           the fragment to insert
     * @return {nothing}                nothing
    ###
    _insertFrag : (targetContainer, targetOffset, frag) ->
            # for sourceNode in frag
            #     if targetContainer.nodeName == sourceNode.nodeName
            #         switch targetContainer.nodeName 
            #             when '#text'
            #                 # insert text
            #                 targetContainer.textContent = targetContainer.textContent.substring(0,targetOffset)+sourceNode.textContent+targetContainer.textContent.substring(targetOffset)
            #             when 'SPAN'
            #                 _insertFrag()
            #                 targetContainer = targetContainer.childNodes[targetOffset]

            if targetOffset == 0
                range = document.createRange()
                range.setStart(startContainer,startOffset)
                range.setEnd(startContainer,startOffset)
                range.insertNode(frag)
                range.detach()
            else
                if frag.childNodes.length>0
                    targetNode = targetContainer.childNodes[targetOffset-1]
                    targetNode.textContent += frag.firstChild.textContent



    ###*
     * Walks thoug an html tree in order to convert it in a strutured content
     * that fit to a note structure.
     * @param  {html element} elemt   Reference to an html element to be parsed
     * @param  {object} context _domWalk is recursive and its context of execution
     *                  is kept in this param instead of using the editor context
     *                  (quicker and better) isolation
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



    ###*
     * Walks thoug an html tree in order to convert it in a strutured content
     * that fit to a note structure.
     * @param  {html element} nodeToParse   Reference to an html element to 
     *                        be parsed
     * @param  {object} context __domWalk is recursive and its context of 
     *                          execution is kept in this param instead of 
     *                          using the editor context (quicker and better) 
     *                          isolation
    ###
    __domWalk : (nodeToParse, context) ->
        absDepth    = context.absDepth
        prevHxLevel = context.prevHxLevel
        
        console.log "node to parse"
        
        # loop on the child nodes of the parsed node
        for child in nodeToParse.childNodes
            switch child.nodeName

                when '#text'
                    # text nodes are inserted
                    txtNode = document.createTextNode(child.textContent)
                    
                    if context.currentLineEl.nodeName in ['SPAN','A']
                        context.currentLineEl.appendChild(txtNode)
                    else
                        spaneEl = document.createElement('span')
                        spaneEl.appendChild txtNode
                        context.currentLineEl.appendChild spaneEl

                    console.log "lineEl"
                    console.log context.currentLineEl
                    console.log txtNode
                    
                    
                    @_appendCurrentLineFrag(context,absDepth,absDepth)
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

                when 'BR'
                    # append the line that was being populated to the frag (even
                    # if this one had not yet been populated by any element)
                    @_appendCurrentLineFrag(context,absDepth,absDepth)
                
                when 'A'
                    lastInsertedEl = context.currentLineEl.lastChild
                    if lastInsertedEl != null and lastInsertedEl.nodeName=='SPAN'
                        lastInsertedEl.textContent += '[[' + child.textContent + '|'+ child.href+']]'
                    else
                        spanNode = document.createElement('span')
                        spanNode.textContent = child.textContent + ' [[' + child.href+']] '
                        context.currentLineEl.appendChild(spanNode)
                    context.isCurrentLineBeingPopulated = true
                
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
                when 'DIV'
                    if child.id.substr(0,5)=='CNID_'
                        @_clipBoard_Insert_InternalLine(child, context)
                    else
                        @__domWalk(child, context)
                else
                    lastInsertedEl = context.currentLineEl.lastChild
                    if lastInsertedEl != null and lastInsertedEl.nodeName=='SPAN'
                        lastInsertedEl.textContent += child.textContent
                    else
                        spanNode = document.createElement('span')
                        spanNode.textContent = child.textContent
                        context.currentLineEl.appendChild(spanNode)
                    context.isCurrentLineBeingPopulated = true

        true



    ###*
     * Append to frag the currentLineFrag and prepare a new empty one.
     * @param  {Object} context  [description]
     * @param  {Number} absDepth absolute depth of the line to insert
     * @param  {Number} relDepth relative depth of the line to insert
    ###
    _appendCurrentLineFrag : (context,absDepth,relDepth) ->
        # if the line is empty, add an empty Span before the <br>
        if context.currentLineFrag.childNodes.length == 0
            spanNode = document.createElement('span')
            context.currentLineFrag.appendChild(spanNode)
        p =
            sourceLine         : context.lastAddedLine
            fragment           : context.currentLineFrag
            targetLineType     : "Tu"
            targetLineDepthAbs : absDepth
            targetLineDepthRel : absDepth
        context.lastAddedLine = @_insertLineAfter(p)
        console.log context.currentLineEl
        console.log context.frag
        context.frag.appendChild context.currentLineEl
        # prepare the new lingFrag & lineEl
        context.currentLineFrag = document.createDocumentFragment()
        context.currentLineEl = context.currentLineFrag
        context.isCurrentLineBeingPopulated = false



    ###*
     * Insert in the editor a line that was copied in a cozy note editor
     * @param  {html element} elemt a div ex : <div id="CNID_7" class="Lu-3"> ... </div>
     * @return {line}        a ref to the line object
    ###
    _clipBoard_Insert_InternalLine : (elemt, context)->
        lineClass = elemt.className.split('-')
        lineDepthAbs = +lineClass[1]
        lineClass = lineClass[0]
        if !context.prevCNLineAbsDepth
            context.prevCNLineAbsDepth = lineDepthAbs
        deltaDepth = lineDepthAbs - context.prevCNLineAbsDepth
        if deltaDepth > 0
            # context.absDepth += 1
        else
            # context.absDepth += deltaDepth
        p = 
            sourceLine         : context.lastAddedLine
            innerHTML          : elemt.innerHTML
            targetLineType     : "Tu"
            targetLineDepthAbs : context.absDepth
            targetLineDepthRel : context.absDepth
        context.lastAddedLine = @_insertLineAfter(p)

        
   
    ### ------------------------------------------------------------------------
    #  MARKUP LANGUAGE CONVERTERS
    # _cozy2md (Read a string of editor html code format and turns it into a
    #           string in markdown format)
    # _md2cozy (Read a string of html code given by showdown and turns it into
    #           a string of editor html code)
    ###

    #  BUG --> : an odd bug occurs around the 19-th line in the example :
    #           ./templates/content-shortlines-marker
    #           (there are some empty lines around)
     
    ### ------------------------------------------------------------------------
    #  _cozy2md
    # Read a string of editor html code format and turns it into a string in
    #  markdown format
    ###
    _cozy2md : (text) ->
        
        # Writes the string into a jQuery object
        htmlCode = $(document.createElement 'div').html text
        
        # The future converted line
        markCode = ''

        # current depth
        currDepth = 0
        
        # converts a fragment of a line
        converter = {
            'A': (obj) ->
                title = if obj.attr('title')? then obj.attr('title') else ""
                href  = if obj.attr('href')? then obj.attr('href') else ""
                return '[' + obj.html() + '](' + href + ' "' + title + '")'
                    
            'IMG': (obj) ->
                title = if obj.attr('title')? then obj.attr('title') else ""
                alt   = if obj.attr('alt')? then obj.attr('alt') else ""
                src   = if obj.attr('src')? then obj.attr('src') else ""
                return '![' + alt + '](' + src + ' "' + title + '")'
                
            'SPAN': (obj) ->
                return obj.text()
            }

        
        # markup symbols
        markup = {
            'Th' : (blanks, depth) ->
                # a title is a section rupture
                currDepth = depth
                dieses = ''
                i = 0
                while i < depth
                    dieses += '#'
                    i++
                return "\n" + dieses + ' '
            'Lh' : (blanks, depth) ->
                return "\n"
            'Tu' : (blanks, depth) ->
                return "\n" + blanks + "+   "
            'Lu' : (blanks, depth) ->
                return "\n" + blanks + "    "
            'To' : (blanks, depth) ->
                return "\n" + blanks + "1.   "
            'Lo' : (blanks, depth) ->
                return "\n" + blanks + "    "
            }

        # adds structure depending of the line's class
        classType = (className) ->
            tab   = className.split "-"
            type  = tab[0]               # type of class (Tu,Lu,Th,Lh,To,Lo)
            depth = parseInt(tab[1], 10) # depth (1,2,3...)
            blanks = ''
            i = 1
            while i < depth - currDepth
                blanks += '    '
                i++
            return markup[type](blanks, depth)
        
        # iterate on direct children
        children = htmlCode.children()
        for i in [0..children.length-1]
            
            # fetch the i-th line of the text
            lineCode = $ children.get i
            
            # indent and structure the line
            if lineCode.attr('class')?
                # console.log classType lineCode.attr 'class'
                markCode += classType lineCode.attr 'class'

            # completes the text depending of the line's content
            l = lineCode.children().length
            j = 0
            space = ' '
            while j < l
                lineElt = lineCode.children().get j
                if (j+2==l) then space='' #be sure not to insert spaces after BR
                if lineElt.nodeType == 1 && converter[lineElt.nodeName]?
                    markCode += converter[lineElt.nodeName]($ lineElt) + space
                else
                    markCode += $(lineElt).text() + space
                j++
                
            # adds a new line at the end
            markCode += "\n"
        
        return markCode


    ### ------------------------------------------------------------------------
    # Read a string of html code given by showdown and turns it into a string
    # of editor html code
    ###
    _md2cozy: (text) ->
    
        conv = new Showdown.converter()
        text = conv.makeHtml text
       
        # Writes the string into a jQuery object
        htmlCode = $(document.createElement 'ul').html text

        # final string
        cozyCode = ''
        
        # current line
        id = 0

        # Returns the corresponding fragment of cozy Code
        cozyTurn = (type, depth, p) ->
            # p is a (jquery) object that looks like this :
            # <p> some text <a>some link</a> again <img>some img</img> poof </p>
            # OR like this:  <li> some text <a>some link</a> ...
            # We are treating a line again, thus id must be increased
            id++
            code = ''
            p.contents().each () ->
                name = @nodeName
                if name == "#text"
                    code += "<span>#{$(@).text()}</span>"
                else if @tagName?
                    $(@).wrap('<div></div>')
                    code += "#{$(@).parent().html()}"
                    $(@).unwrap()
            return "<div id=CNID_#{id} class=#{type}-#{depth}>" + code +
                "<br></div>"
                
        # current depth
        depth = 0
        
        # Read sections sequentially
        readHtml = (obj) ->
            tag = obj[0].tagName
            if tag[0] == "H"       # c'est un titre (h1...h6)
                depth = parseInt(tag[1],10)
                cozyCode += cozyTurn("Th", depth, obj)
            else if tag == "P"     # ligne de titre
                cozyCode += cozyTurn("Lh", depth, obj)
            else
                recRead(obj, "u")
                
        # Reads recursively through the lists
        recRead = (obj, status) ->
            tag = obj[0].tagName
            if tag == "UL"
                depth++
                obj.children().each () ->
                    recRead($(@), "u")
                depth--
            else if tag == "OL"
                depth++
                obj.children().each () ->
                    recRead($(@), "o")
                depth--
            else if tag == "LI" && obj.contents().get(0)?
                # cas du <li>Un seul titre sans lignes en-dessous</li>
                if obj.contents().get(0).nodeName == "#text"
                    obj = obj.clone().wrap('<p></p>').parent()
                for i in [0..obj.children().length-1]
                    child = $ obj.children().get i
                    if i == 0
                        cozyCode += cozyTurn("T#{status}", depth, child)
                    else
                        recRead(child, status)
            else if tag == "P"
                cozyCode += cozyTurn("L#{status}", depth, obj)

        htmlCode.children().each () ->
            readHtml $ @
        
        return cozyCode


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
