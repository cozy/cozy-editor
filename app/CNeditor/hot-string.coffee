AutoComplete = require('./autocomplete').AutoComplete
selection    = require('./selection').selection

module.exports = class HotString 
    

    constructor : (editor) ->
        @editor      = editor
        @container = editor.linesDiv
        @_auto = new AutoComplete(editor.linesDiv, editor)
        # @_auto       = editor._auto
        @_hsTypes      = ['@', '@@', '#']
        @_modes        = 
            '@'  : 'contact'
            '@@' : 'reminder'
            '#'  : 'tag'
        @isPreparing  = false # true if a hot sring is under construction
        @_hsType      = ''
        @_hsRight     = ''
        @_hsLeft      = ''
        @_hsString    = ''
        @_currentMode = ''
        # ex 1 : 
        #     typed    = ' @zorro' 
        #     @_hsType = '@'
        #     @_hsString = 'zorro'
        # ex 2 : 
        #     typed    = ' @@23/12/2014 23:33' 
        #     @_hsType = '@@'
        #     @_hsString = '23/12/2014 23:33'
        # ex 3 : 
        #     typed    = ' #factures' 
        #     @_hsType = '#'
        #     @_hsString = 'factures'
        @_getShortCut = editor.getShortCut
        # flag set by newTypedChar (fired by keypress event) when a hot string 
        # has begun to be typed. The aim is to hightlight the hotstring in the 
        # editor when keyup will occur. It can not be done on keypress because
        # the caracter is not yet inserted and the editor can not set a metadata
        # to an empty range.
        @_autoToBeShowed = false
        @container.addEventListener('keyup', @_tryHighlight)



    newShortCut : (shortcut, metaKeyCode, keyCode)->
        # console.log 'newShortCut' , shortcut, metaKeyCode, keyCode
        switch shortcut

            when '-return'
                item = @_auto.hide()
                @isPreparing = false
                @editor.doHotStringAction(item)
                preventDefault = true

            when '-backspace'
                if @_hsLeft.length == 0
                    newType = @_hsType.slice(0, -1)
                    if newType in @_hsTypes
                        @_hsType = newType
                        @_currentMode = @_modes[newType]
                        @_auto.setMode(@_currentMode)
                        @_auto.update(@_hsString)
                    else
                        @reset(true)
                else
                    @_hsLeft = @_hsLeft.slice(0, -1)
                    @_hsString = @_hsLeft + @_hsRight
                    @_auto.update(@_hsString)
                preventDefault = false

            when '-suppr'
                if @_hsRight.length == 0
                    @reset(true)
                else
                    @_hsRight = @_hsRight.slice(1)
                    @_hsString = @_hsLeft + @_hsRight
                    @_auto.update(@_hsString)
                preventDefault = false

            when '-up'
                @_auto.up()
                preventDefault = true

            when '-down'
                @_auto.down()
                preventDefault = true

            when '-left'
                if @_hsLeft.length == 0
                    @reset(true)
                else
                    @_hsRight = @_hsLeft.slice(-1) + @_hsRight
                    @_hsLeft  = @_hsLeft.slice(0, -1)
                preventDefault = false

            when '-right'
                if @_hsRight.length == 0
                    @reset(true)
                else
                    @_hsLeft  = @_hsLeft + @_hsRight[0]
                    @_hsRight = @_hsRight .slice(1)
                preventDefault = false

            when '-pgUp', '-pgDwn', '-end', '-home'
                @reset(true)
                preventDefault = false

            when '-space'
                # @reset()
                preventDefault = false

            # when 'Ctrl-K'

            # when 'Ctrl-S'

            # when 'Ctrl-Z'

            # when 'Ctrl-Y'

            when '-esc'
                @reset(true)
                preventDefault = false


        # @printHotString()
        return preventDefault



    printHotString : () ->
        console.log '_hsType = "'  + @_hsType  + '"' ,
                    '_hsLeft = "'  + @_hsLeft  + '"' ,
                    '_hsRight = "' + @_hsRight + '"'


    ###* -----------------------------------------------------------------------
     * Update the current "hotString" typed by the user. This function is called
     * by keypress event, and detects keys such as '@' and "normal caracters". 
     * Arrows, return, baskspace etc are manage in newShortCut()
     * @param  {Event} e The keyboard event
    ###
    newtypedChar : (e) =>
        # console.log  'newtypedChar'
        charCode = e.which

        if @isPreparing

            if @_hsLeft == '' and charCode == 64 and @_hsType = '@' # '@'  => ' @@'
                @_hsType = '@@'
                @_currentMode = 'reminder'
                @_auto.setMode('reminder')
                # @printHotString()
                return true

            isAction = @_getShortCut(e)[2]
            # 'actions' (return, esc, up, down, right...) are managed 
            # in newShortCut()
            if !isAction
                @_hsLeft  += String.fromCharCode(charCode)
                @_hsString = @_hsLeft + @_hsRight
                # @printHotString()
                autoItem = @_isAHotString(@_hsString)
                if autoItem
                    @editor.doHotStringAction(autoItem)
                    e.preventDefault()
                    return false
                @_auto.update(@_hsString)
                return true

        else if charCode == 64  # '@'
            if @editor._isStartingWord()
                modes = @editor.getCurrentAllowedInsertions()
                if 'contact' in modes
                    @_hsType = '@'
                    @isPreparing = true
                    # @container.addEventListener('mousedown',@_mouseDownCb)
                    # @container.addEventListener('mouseup',@_mouseUpCb)
                    @_auto.setAllowedModes(modes)
                    @_currentMode = 'contact'
                    @_auto.setMode('contact')
                    @_autoToBeShowed = mode:'insertion'

        else if charCode == 35  # '#'
            if @editor._isStartingWord()
                modes = @editor.getCurrentAllowedInsertions()
                if 'tag' in modes
                    @_hsType = '#'
                    @isPreparing = true
                    # @container.addEventListener('mousedown',@_mouseDownCb)
                    # @container.addEventListener('mouseup',@_mouseUpCb)
                    # @_auto.setAllowedModes(modes)
                    @_currentMode = 'htag'
                    @_auto.setMode('htag')
                    @_autoToBeShowed = mode:'insertion'

        # @printHotString()
        return true



    edit : (seg, range) ->
        @_hsType   = '@'
        rg = range.cloneRange()
        rg.setStartBefore(seg)
        @_hsLeft   = rg.toString()
        rg = range.cloneRange()
        rg.setEndAfter(seg)
        @_hsRight  = rg.toString()
        @_hsString = seg.textContent

        @isPreparing = true
        # @container.addEventListener('mousedown',@_mouseDownCb)
        # @container.addEventListener('mouseup',@_mouseUpCb)
        modes = @editor.getCurrentAllowedInsertions()
        @_auto.setAllowedModes(modes)
        @_currentMode = 'contact'
        @_auto.setMode('contact')
        @_autoToBeShowed = mode:'edit',segment:seg
        @_tryHighlight()



    _isNormalChar : (charCode) ->
        res =  96 < charCode < 123  or   \  # a .. z
               63 < charCode < 91   or   \  # @A .. Z
               47 < charCode < 58   or   \  # 0 .. 9
               charCode in [43]             # +

        # console.log 'isNormal = ', res, '(' + charCode + ')'
        return res



    _tryHighlight : () =>

        if !@_autoToBeShowed
            return true

        switch @_autoToBeShowed.mode
            when 'edit'
                @_hsSegment  = @_autoToBeShowed.segment
                @_hsTextNode = @_hsSegment.firstChild
                @_hsSegment.classList.add('CNE_hot_string')
                @_autoToBeShowed = false
                @_auto.show(@_hsSegment , @_hsString)
                
            when 'insertion'
                rg = @editor.getEditorSelection().getRangeAt(0)
                @editor.setSelection(
                    rg.startContainer                    , 
                    rg.startOffset - @_hsType.length     ,
                    rg.endContainer                      , 
                    rg.endOffset
                )
                rg = @editor._applyMetaDataOnSelection('CNE_hot_string')
                @_hsTextNode = rg.startContainer
                @_hsSegment  = rg.startContainer.parentElement
                @editor._setCaret(@_hsSegment, @_hsSegment.childNodes.length)
                @_autoToBeShowed = false
                @_auto.show(@_hsSegment , '')
        
        return true



    _unhighLight : (bps) ->
        seg = @_hsSegment
        if seg.parentElement # seg might have already been removed of the line
            seg.classList.remove('CNE_hot_string')
            # bp =
            #     cont   : @_hsTextNode
            #     offset : @_hsType.length + @_hsLeft.length
            @editor._fusionSimilarSegments(seg.parentElement, bps)
            # if dealCaret
            #     @editor._setCaret(bp.cont,bp.offset)
            @_hsTextNode = null
            @_hsSegment  = null
        return true
            


    _forceUserHotString : (newHotString, bps) ->
        textNode = @_hsTextNode
        textNode.textContent = newHotString
        for bp in bps
            if bp.cont == textNode
                bp.offset = newHotString.length
        return bps
        # if setEnd
        #     @editor._setCaret(textNode,textNode.length) 
        # else
        #     @editor._setSelectionOnNode(textNode) 



    forceHsType : (type) ->
        switch type

            when 'todo'
                return @editor.doHotStringAction(type:'todo')
                
            when 'reminder'
                # hs._auto.hide()
                bp = 
                    cont  : @_hsTextNode
                    offset: @_hsTextNode.length
                @._forceUserHotString('@@',[bp])
                @editor._setCaret(bp.cont, bp.offset)
                @._hsType = '@@'
                @_currentMode = 'reminder'
                @._auto.setMode('reminder')
                return true

            when 'htag'
                @._auto.hide()
                bp = 
                    cont  : @_hsTextNode
                    offset: @_hsTextNode.length
                @._forceUserHotString('#',[bp])
                @editor._setCaret(bp.cont, bp.offset)
                @._hsType   = '#'
                @._hsString = ''
                @._hsRight  = ''
                @._hsLeft   = ''
                @_currentMode = 'htag'
                @._auto.setMode('htag')
                @._auto.show(@._hsSegment , @._hsString)
                return true



    reset : (dealCaret) ->

        if dealCaret
            bp =
                cont  : @_hsTextNode
                offset: @_hsTextNode.length
            @_unhighLight([bp])
            
        else
            @_unhighLight([])

        @_reInit()
        @_auto.hide()
        
        if dealCaret
            @editor._setCaret(bp.cont, bp.offset)

        return true



    _reInit : () ->
        @_hsType     = ''
        @_hsString   = ''
        @_hsRight    = ''
        @_hsLeft     = ''
        @isPreparing = false
        # @container.removeEventListener('mousedown',@_mouseDownCb)
        # @container.removeEventListener('mouseup',  @_mouseUpCb  )
        # @printHotString()



    _isAHotString : (txt) ->
        switch txt
            when 'reminder'
                return text:'reminder', type:'ttag', value:'reminder'
            when 'todo'
                return text:'todo', type:'ttag', value:'todo'
            when 'tag'
                return text:'tag', type:'ttag', value:'htag'



    mouseDownCb : (e) ->
        console.log '== mousedown'
        # detect if click is in the list or out
        isOut =     e.target != @el                                    \
                and $(e.target).parents('#CNE_autocomplete').length == 0
        if !isOut
            e.preventDefault()



    mouseUpCb : (e) ->
        console.log '== mouseup'
        
        sel = @editor.getEditorSelection()
        rg = sel.getRangeAt(0)

        if rg.startContainer == @_hsSegment
            rg = range.cloneRange()
            rg.setStartBefore(seg)
            @_hsLeft   = rg.toString()
            rg = range.cloneRange()
            rg.setEndAfter(seg)
            @_hsRight  = rg.toString()
            @_hsString = seg.textContent
            return true
            
        # detect if click is in the list or out
        isIn =     e.target == @el                                             \
                or $(e.target).parents('#CNE_autocomplete').length != 0
        
        if isIn
        
            if @_currentMode == 'reminder'
                return true
        
            selectedLine = e.target
            while selectedLine && selectedLine.tagName != ('LI')
                selectedLine = selectedLine.parentElement
            if selectedLine
                @editor.doHotStringAction(selectedLine.item)

            else
                @reset(true)

        else
            @reset(false)
            return true
                
