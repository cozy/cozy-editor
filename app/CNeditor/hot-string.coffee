AutoComplete = require('./autocomplete').AutoComplete
selection    = require('./selection').selection

module.exports = class HotString 
    

    constructor : (editor) ->
        @editor    = editor
        @_isEdit   = false
        @container = editor.linesDiv
        @_auto     = new AutoComplete(editor.linesDiv, editor, this)
        # @_auto       = editor._auto
        @_hsTypes  = ['@', '@@', '#']
        @_modes    = 
            '@'  : 'contact'
            '@@' : 'reminder'
            '#'  : 'htag'
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


    ###* -----------------------------------------------------------------------
     * Called by the editor keydown call back.
     * @param  {Object} shortcut cf editor.getShortcut(e)
     * @return {Boolean}          True if keydown should be preventDefaulted
    ###
    keyDownCb : (shortcut)->

        # console.log 'newShortCut' , shortcut, metaKeyCode, keyCode
        switch shortcut

            when '-return'
                @validate()
                preventDefault = true

            when '-up'
                @_auto.up()
                preventDefault = true

            when '-down'
                @_auto.down()
                preventDefault = true

            # when '-left'
            
            # when '-right'
            
            when '-pgUp', '-pgDwn', '-end', '-home'
                @reset(false)
                preventDefault = false

            when '-space'
                preventDefault = false

            # when 'Ctrl-K'

            # when 'Ctrl-S'

            # when 'Ctrl-Z'

            # when 'Ctrl-Y'

            when '-esc'
                @reset('end')
                preventDefault = false

        return preventDefault



    printHotString : () ->
        console.log '_hsType = "'  + @_hsType  + '"' ,
                    '_hsLeft = "'  + @_hsLeft  + '"' ,
                    '_hsRight = "' + @_hsRight + '"'


    ###* -----------------------------------------------------------------------
     * Update the current "hotString" typed by the user. This function is called
     * by editor._keypressCb(), and detects keys such as '@' and "normal 
     * caracters". 
     * Actions (Arrows, return, baskspace etc...) are managed in newShortCut()
     * @param  {Event} e The keyboard event
    ###
    keypressCb : (e) ->
        # console.log  'hotstring.keypressCb()'
        charCode = e.which

        if @isPreparing

        else if charCode == 64  # '@'
            if @editor._isStartingWord()
                modes = @editor.getCurrentAllowedInsertions()
                if 'contact' in modes
                    @_hsType = '@'
                    @isPreparing = true
                    @_auto.setAllowedModes(modes)
                    @_currentMode = 'contact'
                    @_auto.setMode('contact')
                    @_autoToBeShowed = mode:'insertion'

        else if charCode == 35  # '#'
            if @editor._isStartingWord()
                modes = @editor.getCurrentAllowedInsertions()
                if 'htag' in modes
                    @_hsType = '#'
                    @isPreparing = true
                    @_currentMode = 'htag'
                    @_auto.setMode('htag')
                    @_autoToBeShowed = mode:'insertion'
        # else if charCode == 37 # left
        #     if selection.


        # @printHotString()
        return true


    ###* -----------------------------------------------------------------------
     * Called by editor._keyupCb() if a hotstring is preparing.
     * It will check if the content of _hsSegment has change and then take the
     * appropriate actions (update autocomplete, change mode, reset)
    ###
    updateHs : (seg) ->
        # console.log "== updateHs"
        if !seg
            seg = @_hsSegment

        # 1- Check if hsString has changed
        newHotStrg = @_hsSegment.textContent
        if @_hsType + @_hsString == newHotStrg
            return true

        # 2- Find the new hsType
        hsType = newHotStrg.slice(0,2)
        if hsType == '@@'
            @_hsString = newHotStrg.slice(2)
        else
            hsType = hsType[0]
            if hsType in ['@', '#']
                @_hsString = newHotStrg.slice(1)
            else
                @reset('current', true)
                return true

        # 3- Check if hsType has changed
        if hsType != @_hsType
            @_hsType = hsType
            mode = @_modes[hsType]
            @_currentMode = mode
            @_auto.setMode(mode)
            return true

        # 4- Test if newHotStrg corresponds to an action. If not update
        # auto complete
        else
            autoItem = @_isAHotString(@_hsString)
            if autoItem
                @editor.doHotStringAction(autoItem)
                return false
            @_auto.update(@_hsString)



    ###* -----------------------------------------------------------------------
     * Called by editor._keyupCb() and editor._mouseupCb() which detect if the
     * carret enters a meta segment. If yes, then we edit it.
     * @param  {Element} seg   The segment with meta data (reminder, contact...)
     * @param  {Range} range The range of the selection
    ###
    edit : (seg, range) ->
        console.log 'hotstring.edit()'
        @_isEdit = true
        @isPreparing = true

        type = seg.dataset.type

        switch type
            when 'reminder'
                @_hsType   = '@@'
                segClass   = 'CNE_reminder'
            when 'contact'
                @_hsType   = '@'
                segClass   = 'CNE_contact'
            when 'htag'
                @_hsType   = '#'
                segClass   = 'CNE_htag'


        @_editedItem = 
            text : seg.textContent
            type : seg.dataset.type
            id   : seg.dataset.id
            value: seg.dataset.value

        # rg = range.cloneRange()
        startOffset = range.startOffset + @_hsType.length
        endOffset   = range.endOffset   + @_hsType.length

        @_hsTextNode = seg.firstChild
        @_hsTextNode.textContent = @_hsType + seg.textContent
        seg.classList.remove(segClass)
        seg.dataset.type = ''
        @editor.setSelection(seg.firstChild, startOffset ,
                             seg.firstChild, endOffset
        ) 
        @_hsString = seg.textContent
        modes = @editor.getCurrentAllowedInsertions()
        @_auto.setAllowedModes(modes)
        @_currentMode = type
        @_auto.setMode(type)
        @_autoToBeShowed = mode:'edit',segment:seg
        @_tryHighlight()

        while false
            d = d

        return true
        # bp = 
        #     cont : range.startContainer
        #     offset: range.startOffset
        # @editor._setCaret(bp.cont,bp.offset+1) 



    _isNormalChar : (charCode) ->
        res =  96 < charCode < 123  or   \  # a .. z
               63 < charCode < 91   or   \  # @A .. Z
               47 < charCode < 58   or   \  # 0 .. 9
               charCode in [43]             # +

        # console.log 'isNormal = ', res, '(' + charCode + ')'
        return res


    ###*
     * In charge of diplaying the hotstring segment and the auto completion div
     * when a creation or edition begins.
    ###
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
            @editor._fusionSimilarSegments(seg.parentElement, bps)
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


    validate : () ->
        item = @_auto.getSelectedItem()
        @editor.doHotStringAction(item)

    ###* -----------------------------------------------------------------------
     * Reset hot string : the segment is removed and autocomplete hidden. In 
     * case where it was not a creation of a meta but a modification, then the
     * initial value of the meta is restored. If the hsType ('@', '#' or '@@')
     * has been deleted then the meta data segment is also removed if editing.
     * @param  {String} dealCaret  3 values : 1/ 'current'the current caret 
     *                  position is saved and restored after. 2/ 'end' : the 
     *                  caret will be set at the end of the segment. 3/ false :
     *                  the carret is not managed here.
    ###
    reset : (dealCaret, hardReset) ->
        # console.log 'hotString.rest()'
        
        if !@isPreparing
            return true

        # if we are editing an already existing segment with meta data and that 
        # the edition is canceled (but reset not forced)
        if @_isEdit and !hardReset
            if dealCaret == 'current'
                rg = @editor.getEditorSelection().getRangeAt(0)
                startContainer = rg.startContainer
                startOffset    = rg.startOffset
                endContainer   = rg.endContainer
                endOffset      = rg.endOffset
                @editor.doHotStringAction(@_editedItem)
                @editor.setSelection(startContainer,startOffset,
                    endContainer,endOffset)
            else
                @editor.doHotStringAction(@_editedItem)
            return true

        # else, reset : remove highlight, hide auto, réinit, deal caret.
        if dealCaret == 'current'
            rg = @editor.getEditorSelection().getRangeAt(0)
            bp =
                cont   : rg.startContainer
                offset : rg.startOffset
            @_unhighLight([bp])
        else if dealCaret == 'end'
            bp =
                cont   : @_hsTextNode
                offset : @_hsTextNode.length
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
        @_isEdit     = false



    _isAHotString : (txt) ->
        switch txt
            when 'reminder'
                return text:'reminder', type:'ttag', value:'reminder'
            when 'todo'
                return text:'todo', type:'ttag', value:'todo'
            when 'tag'
                return text:'tag', type:'ttag', value:'htag'



    mouseDownCb : (e) ->
        # console.log '== mousedown'
        # detect if click is in the list or out
        isOut =     e.target != @el                                    \
                and $(e.target).parents('#CNE_autocomplete').length == 0
        if !isOut
            e.preventDefault()



    mouseUpInAutoCb : (e) ->
            
        # if click in reminder, let the components deal actions.
        if @_currentMode == 'reminder'
            return true
        
        # else 
        selectedLine = e.target
        while selectedLine && selectedLine.tagName != ('LI')
            selectedLine = selectedLine.parentElement
        if selectedLine
            @editor.doHotStringAction(selectedLine.item)
        else
            @reset('end')


        
    isInAuto : (elt) ->
        return elt == @el or $(elt).parents('#CNE_autocomplete').length != 0
