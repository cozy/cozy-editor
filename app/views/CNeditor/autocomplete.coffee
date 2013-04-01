
# Exports a single task
class AutoComplete
    
    constructor : (container) ->
        
        @container = container
        @items = []
        @regexStore = {}
        @isVisible = false

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
        @el = auto
        # console.log '== AutoComplete', this.items
        @addItem(text:'@reminder', type:'tag', mention:' (@@)')
        @addItem(text:'@todo', type:'tag')
        @addItem(text:'@contact', type:'tag', mention:' (@)')
        @addItem(text:'@tag', type:'tag', mention:' (#)')
        return this

    update : (typedTxt) ->
        if !@isVisible
            return
        @_updateDisp(typedTxt)

    addItem : (item) ->
        # console.log ' addItem', @items
        @items.push(item)

    up : () ->
        if !@_selectedLine
            @_selectedLine = @el.lastChild
            @_selectLine()
        else
            @_unSelectLine()
            @_selectedLine = @_selectedLine.previousSibling
            if !@_selectedLine
                @_selectedLine = @el.lastChild
            @_selectLine()

    down : () ->
        if !@_selectedLine
            @_selectedLine = @el.firstChild
            @_selectLine()
        else
            @_unSelectLine()
            @_selectedLine = @_selectedLine.nextSibling
            if !@_selectedLine
                @_selectedLine = @el.firstChild
            @_selectLine()


    val : () ->
        return @_selectedLine.item.text


    show : (currentSel,typedTxt) ->
        @_updateDisp(typedTxt)
        @_position(currentSel)
        @container.appendChild(@el)
        @isVisible = true

    _updateDisp : (typedTxt) ->

        # check the items to show
        for item in @items
            item.isToDisp = @_shouldDisp(item,typedTxt)

        # sort items to show
        @_sortItems()
        
        # go throw items and update the display
        line = @el.firstChild
        for item in @items
            if item.isToDisp
                if line == null
                    line = @_addLine(item)
                else
                    @_updateLine(line,item)
                line = line.nextSibling
        while line
            line.style.display = 'none'
            line = line.nextSibling

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
        line.className = 'SUGG_line'
        @_updateLine(line,item)

        line.addEventListener('mouseover',@_mouseoverCB)
        line.addEventListener('mouseout', @_mouseoutCB)
        @el.appendChild(line)
        return line

    _updateLine : (line,item) ->
        line.style.display = 'block'
        line.innerHTML = ''
        span = document.createElement('SPAN')
        span.textContent = item.text
        if item.type == 'tag'
            span.className = 'tag'
        line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'mention'
            line.appendChild(span)

        line.item = item

    _selectLine : () ->
        @_selectedLine.classList.add('SUGG_selected')

    _unSelectLine : () ->
        @_selectedLine.classList.remove('SUGG_selected')

    _removeLine : (line)->
        line.removeEventListener(@_mouseoverCB)
        line.removeEventListener(@_mouseoutCB)
        @el.removeChild(line)

    _mouseoverCB : (event) ->
        # this.className = 'SUGG_line SUGG_selected'

    _mouseoutCB : (event) ->
        # this.className = 'SUGG_line'

    hide : () ->
        if !@isVisible
            return
        @container.removeChild(@el)
        @_unSelectLine()
        @_selectedLine = null
        @isVisible = false

    _shouldDisp : (item,typedTxt) ->
        if @regexStore[typedTxt]
            reg = @regexStore[typedTxt]
        else
            reg = new RegExp(typedTxt.split('').join('\\w*').replace(/\W/, ""), 'i')
            @regexStore[typedTxt] = reg
        if item.text.match(reg)
            return true
        else
            return false

exports.AutoComplete = AutoComplete