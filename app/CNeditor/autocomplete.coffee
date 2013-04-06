

# Exports a single task
class AutoComplete
    

    constructor : (container, editor) ->
        
        @container  = container
        @editor     = editor
        @tTags       = [] # types of tags
        @tTagsDiv    = document.createElement('DIV')
        @contacts    = [] # items of contact
        @contactsDiv = document.createElement('DIV')
        @regexStore = {}
        @isVisible  = false

        auto  = document.createElement('div')
        auto.id = 'CNE_autocomplete'
        auto.className = 'CNE_autocomplete'
        auto.setAttribute('contenteditable','false')
        auto.addEventListener 'keypress', (e) =>
            if e.keyCode == 13 # return
                @_validateUrlPopover()
                e.stopPropagation()
            else if e.keyCode == 27 # esc
                @_cancelUrlPopover(false)
            return false
        auto.appendChild(@tTagsDiv)
        @el = auto

        # default mode = contact : will be overriden when show is called
        @_currentMode = 'contact'
        auto.appendChild(@contactsDiv)

        @setItems( 'tTags', [
            {text:'contact'         , type:'ttag', mention:' (@)' }
            {text:'reminder'        , type:'ttag', mention:' (@@)'}
            {text:'todo'            , type:'ttag'                 }
            {text:'tag'             , type:'ttag', mention:' (#)' }
            ])

        @setItems( 'contact', [
            {text:'Frank @Rousseau' , type:'contact'             }
            {text:'Lucas Toulouse'  , type:'contact'             }
            {text:'Maxence Cote'    , type:'contact'             }
            {text:'Joseph Silvestre', type:'contact'             }
            {text:'Romain Foucault' , type:'contact'             }
            {text:'Zoé Bellot'      , type:'contact'             }
            ])

        return this


    setItems : (type, items) ->
        # console.log ' setItems', items, type
        switch type
            when 'tTags'
                @tTags = items
                lines = @tTagsDiv
            when 'contact'
                @contacts = items
                lines = @contactsDiv
        for it in items
            lines.appendChild(@_createLine(it))

        return true


    _createLine : (item) ->
        console.log '_createLine', item

        line = document.createElement('LI')

        type = item.type
        switch type
            when 'ttag'
                line.className = 'SUGG_line_ttag'
            when 'contact'
                line.className = 'SUGG_line_contact'
        # if line.childNodes.length != 0
        #     line.innerHTML = ''

        t = item.text.split('')
        for c in t
            span = document.createElement('SPAN')
            span.textContent = c
            line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'mention'
            line.appendChild(span)

        line.item = item
        item.line = line

        return line


    ###*
     * Show the suggestion list
     * @param  {Object} currentSel The editor current selection
     * @param  {String} typedTxt   The string typed by the user (hotstring)
     * @param  {[type]} edLineDiv  The editor line div where the user is typing
    ###
    show : (currentSel,typedTxt,edLineDiv,modes) ->
        # modes = ['todo','contact','event','reminder','tag']
        @_currentEdLineDiv = edLineDiv
        @_setModes(modes)
        @_updateDisp(typedTxt)
        @_position(currentSel)
        @container.appendChild(@el)
        @isVisible = true

        # add event listener to detect a click outside of the popover
        @container.addEventListener('mousedown',@_detectMousedownAuto)
        @container.addEventListener('mouseup',@_detectMouseupAuto)

                
    _setModes : (modes) ->
        @_modes = modes
        for ttag in @tTags
            for m in modes
                if ttag.text == m
                    ttag.isInMode = true
                    break
        if modes[0] == @_currentMode
            return
        switch modes[0]
            when 'contact'
                @el.removeChild(@el.lastChild)
                @el.appendChild(@contactsDiv)
                @_currentMode = 'contact'
        

    _updateDisp : (typedTxt) ->

        # check the ttags to show
        for ttag in @tTags
            if ttag.isInMode && @_shouldDisp(ttag,typedTxt)
                ttag.line.style.display = 'block'
            else 
                ttag.line.style.display = 'none'

        # line = @el.firstChild
        # for ttag in @tTags
        #     if ttag.isToDisp
        #         if line == null
        #             line = @_addLine(ttag)
        #         else
        #             @_updateLine(line,ttag, typedTxt)
        #         line = line.nextSibling

        items = @contacts

        # check the items to show
        for it in items
            if @_shouldDisp(it,typedTxt)
                it.line.style.display = 'block'
            else 
                it.line.style.display = 'none'


        # sort items to show
        @_sortItems()
        
        # go throught items and update the display
        # for it in items
        #     if it.isToDisp
        #         if line == null
        #             line = @_addLine(it)
        #         else
        #             @_updateLine(line,it, typedTxt)
        #         line = line.nextSibling

        # while line
        #     line.style.display = 'none'
        #     line = line.nextSibling

        return true


    _position : (currentSel) ->
        span = document.createElement('SPAN')
        targetRange = currentSel.theoricalRange
        targetRange.insertNode(span)
        @el.style.left = span.offsetLeft + 'px'
        @el.style.top = span.offsetTop + 17 + 'px'
        parent = span.parentNode
        span.parentNode.removeChild(span)
        parent.normalize()
        currentSel.range.collapse(true)
        return true


    _sortItems : () ->



    _addLine : (item) ->
        line = document.createElement('LI')
        # line.className = 'SUGG_line'
        @_updateLine(line,item)
        # line.addEventListener('click',@_clickCB)
        @el.appendChild(line)
        return line


    _updateLine : (line,item, typedTxt) ->
        console.log '_updateLine'
        type = item.type
        switch type
            when 'tag'
                line.className = 'SUGG_line_tag'
            when 'contact'
                line.className = 'SUGG_line_contact'
        if line.childNodes.length != 0
            line.innerHTML = ''

        t = item.text.split('')
        for c in t
            span = document.createElement('SPAN')
            span.textContent = c
            line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'mention'
            line.appendChild(span)

        line.item = item


    _selectLine : () ->
        if @_selectedLine
            @_selectedLine.classList.add('SUGG_selected')


    _unSelectLine : () ->
        if @_selectedLine
            @_selectedLine.classList.remove('SUGG_selected')


    _removeLine : (line)->
        # line.removeEventListener(@_mouseoverCB)
        # line.removeEventListener(@_mouseoutCB)
        @el.removeChild(line)

    # _clickCB : (event) ->
    #     this.className = 'SUGG_line SUGG_selected'

    # _mouseoutCB : (event) ->
        # this.className = 'SUGG_line'


    hide : () ->
        if !@isVisible
            return false
        @container.removeChild(@el)
        @_currentEdLineDiv = null
        @container.removeEventListener('mousedown',@_detectMousedownAuto)
        @container.removeEventListener('mouseup',@_detectMouseupAuto)
        if @_selectedLine
            @_unSelectLine()
            item = @_selectedLine.item
        else
            item = null
        @_selectedLine = null
        @isVisible = false
        return item


    _shouldDisp : (item,typedTxt) ->
        if @regexStore[typedTxt]
            reg = @regexStore[typedTxt]
        else
            reg = new RegExp(typedTxt.split('').join('[\\w ]*'), 'i')
            @regexStore[typedTxt] = reg
        if item.text.match(reg)
            cs = typedTxt.toLowerCase().split('')
            c = cs.shift()
            for s in item.line.childNodes
                if s.textContent.toLowerCase() == c
                    s.className = 'b'
                    c = cs.shift()
                    if c
                        continue
                    else
                        break
                else
                    s.className = ''
            return true
        else
            return false

    update : (typedTxt) ->
        if !@isVisible
            return
        @_updateDisp(typedTxt)


    up : () ->

        if !@_selectedLine
            @_selectedLine = @el.lastChild.lastChild

        else
            @_unSelectLine()
            prev = @_selectedLine.previousSibling
            if prev
                @_selectedLine = prev
            else
                if @_selectedLine.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.lastChild
                else
                    @_selectedLine = @el.firstChild.lastChild

        if @_selectedLine.style.display == 'none'
            @up()
        else
            @_selectLine()

        return true


    down : () ->
        if !@_selectedLine
            @_selectedLine = @el.firstChild.firstChild

        else
            @_unSelectLine()
            next = @_selectedLine.nextSibling
            if next
                @_selectedLine = next
            else
                if @_selectedLine.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.firstChild
                else
                    @_selectedLine = @el.firstChild.firstChild

        if @_selectedLine.style.display == 'none'
            @down()
        else
            @_selectLine()


    val : () ->
        return @_selectedLine.item


    isInItems : (text) ->
        for item in @_items
            if text == item.text
                return item
        return false


    _detectMousedownAuto : (e) =>
        console.log '== mousedown'
        e.preventDefault()


    _detectMouseupAuto : (e) =>
        console.log '== mouseup'
        # detect if click is in the list or out
        isOut =     e.target != @el                                    \
                and $(e.target).parents('#CNE_autocomplete').length == 0
        if isOut
            @hide()
        else
            # _selectedLine = $(e.target).parents('#SUGG_line')[0]
            selectedLine = e.target
            while selectedLine && !selectedLine.classList.contains('SUGG_line')
                selectedLine = selectedLine.parentElement
            if selectedLine
                @editor._doHotStringAction(selectedLine.item,@_currentEdLineDiv)
                @hide()
            else
                @hide()

exports.AutoComplete = AutoComplete