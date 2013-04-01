
# Exports a single task
class AutoComplete
    
    constructor : (container) ->
        
        @container = container
        @items = []

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
        @addItem(text:'@reminder (@@)', type:'tag')
        @addItem(text:'@todo', type:'tag')
        @addItem(text:'@contact (@)', type:'tag')
        @addItem(text:'@tag (#)', type:'tag')
        return this

    update : (typedTxt) ->
        @_updateDisp(typedTxt)

    addItem : (item) ->
        # console.log ' addItem', @items
        @items.push(item)

    up : () ->


    down : () ->


    val : () ->


    show : (targetRange,typedTxt) ->
        @_updateDisp(typedTxt)
        @_position(targetRange)
        @container.appendChild(@el)

    _updateDisp : (typedTxt) ->
        for item in @items
            item.isToDisp = @_shouldDisp(item,typedTxt)
        @_sortItems()
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

    _position : () ->


    _sortItems : () ->


    _addLine : (item) ->
        line = document.createElement('LI')
        html = "<span class='light'> "+ item.text + "</span>" + "<span class='light'> light</span>"+ "<span class='strong'> strong</span>"
        line.innertHTML = html
        line.className = 'SUGG_line'
        line.item = item
        line.addEventListener('mouseover',@_mouseoverCB)
        line.addEventListener('mouseout', @_mouseoutCB)
        @el.appendChild(line)
        return line

    _updateLine : (line,item) ->
        line.textContent = item.text
        line.item = item

    _removeLine : (line)->
        line.removeEventListener(@_mouseoverCB)
        line.removeEventListener(@_mouseoutCB)
        @el.removeChild(line)

    _mouseoverCB : (event) ->
        # this.className = 'SUGG_line SUGG_selected'

    _mouseoutCB : (event) ->
        # this.className = 'SUGG_line'

    hide : () ->
        @container.removeChild(@el)

    _shouldDisp : (item) ->
        return true

exports.AutoComplete = AutoComplete