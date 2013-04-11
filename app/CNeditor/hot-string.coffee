module.exports = class HotString 
    

    constructor : (editor) ->
        @ed = editor


    isNormalChar : (e) ->
        keyCode = e.which
        res = !e.altKey && !e.ctrlKey && !e.shiftKey &&  \
               96 < keyCode < 123  or   \  # a .. z
               63 < keyCode < 91   or   \  # @A .. Z
               47 < keyCode < 58   or   \  # 0 .. 9
               keyCode in [43]             # +

        # console.log 'isNormal = ', res, '(' + keyCode + ')'
        return res


    ###* -----------------------------------------------------------------------
     * Update the current "hotString" typed by the user. This function is called
     * by keypress event, and detects keys such as '@' and "normal caracters". 
     * Arrows, return, baskspace etc are manage in _keyDownCallBack()
     * @param  {[type]} e [description]
     * @return {[type]}   [description]
    ###
    _hotStringDetectionKeypress : (e) =>
        char = String.fromCharCode(e.which)
        # console.log '.'
        # console.log '=====  hotStringDetectionKeypress()', char, e.which, e.keyCode, e.altKey, '-' + @hotString + '-'
        # initialHotString = @hotString

        if e.which == 64  # '@'
            if @hotString == ' ' or @_isStartingWord()
                @hotString = ' @'
                sel = @updateCurrentSel()
                if sel.startLineDiv.dataset.type == 'task'
                    @_auto.setModes(['contact','event','reminder','tag'])
                else
                    @_auto.setModes(['contact','todo','event','reminder','tag'])
                    # modes = ['reminder']
                @_auto.show(sel , '', sel.startLineDiv)
                return

        if e.which == 35  # '#'
            if @hotString == ' ' or @_isStartingWord()
                @hotString = ' #'
                sel = @updateCurrentSel()
                @_auto.setModes(['tag'])
                @_auto.show(sel , '', sel.startLineDiv)
                return

        if @isNormalChar(e)
            if @hotString.length > 1
                @hotString += String.fromCharCode(e.which)
                @_auto.update(@hotString.slice(2))
                if @_doHotStringAction()
                    e.preventDefault()
            else
                @hotString = ''
                @_auto.hide()


    _isAHotString : (txt) ->
        switch txt.slice(2)
            when 'reminder', '@'
                return text:'reminder', type:'ttag'
            when 'todo'
                return text:'todo', type:'ttag'
            

    _doHotStringAction : (autoItem, lineDiv) ->
        if !autoItem
            autoItem = @_isAHotString(@hotString)
            if !autoItem
                return false

        switch autoItem.type
            when 'ttag'
                switch autoItem.text
                    when 'todo'
                        taskDiv = @_turnIntoTask()
                        if taskDiv
                            txt = taskDiv.textContent.trim()
                            reg = new RegExp('^ *@?t?o?d?o? *$','i')
                            if txt.match(reg)
                                @_initTaskContent(taskDiv)
                            else
                                @_forceUserHotString('')
                            @hotString = ''
                            @_auto.hide()
                            return true
                    when 'reminder'
                        @_auto.hide()
                        @_forceUserHotString(' @@',true)
                        @hotString = ' @@'
                        @_auto.setModes(['reminder'])
                        @_auto.show(null , @hotString.slice(2), null)
                        return true
                    when 'tag'
                        @_auto.hide()
                        @_forceUserHotString(' #',true)
                        @hotString = ' #'
                        @_auto.setModes(['tag'])
                        @_auto.show(null , @hotString.slice(2), null)
                        return true

            when 'contact'
                @_forceUserHotString(autoItem.text)
                rg = @_applyMetaDataOnSelection('CNE_contact')
                lastSeg = selection.getSegment(rg.endContainer,0)
                newSeg = @_insertSegmentAfterSeg(lastSeg)
                @_setCaret(newSeg,1)
                @hotString = ''
                @_auto.hide()
                return true

            when 'htag'
                @_forceUserHotString(autoItem.text)
                rg = @_applyMetaDataOnSelection('CNE_htag')
                lastSeg = selection.getSegment(rg.endContainer,0)
                newSeg = @_insertSegmentAfterSeg(lastSeg)
                @_setCaret(newSeg,1)
                @hotString = ''
                @_auto.hide()
                return true

            when 'reminder'
                format = (n)->
                    if n.toString().length == 1
                        return '0' + n
                    else
                        return n
                date = autoItem.text
                d  = format(date.getDate()     )
                m  = format(date.getMonth()    )
                y  = format(date.getFullYear() )
                h  = format(date.getHours()    )
                mn = format(date.getMinutes()  )
                txt = d + '/' + m + '/' + y + '  ' + h + ':' + mn
                @_forceUserHotString(txt)
                rg = @_applyMetaDataOnSelection('CNE_reminder')
                lastSeg = selection.getSegment(rg.endContainer,0)
                newSeg = @_insertSegmentAfterSeg(lastSeg)
                @_setCaret(newSeg,1)
                @hotString = ''
                @_auto.hide()
                return true

        @_auto.hide() 
        return false
