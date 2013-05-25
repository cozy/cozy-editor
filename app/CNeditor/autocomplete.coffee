require('./bootstrap-datepicker')
require('./bootstrap-timepicker')

# Exports a single task
class AutoComplete


    constructor : (container, editor, hotString) ->

        @container  = container
        @editor     = editor
        @hotString  = hotString
        @tTags       = [] # types of tags
        @tTagsDiv    = document.createElement('DIV')
        @tTagsDiv.className = 'SUGG_ttags'
        @contacts    = [] # items of contact
        @contactsDiv = document.createElement('DIV')
        @reminderDiv = document.createElement('DIV')
        @htagDiv     = document.createElement('DIV')
        @reminderDiv.innerHTML =
        """
            <div class="reminder-title">Add a reminder</div>
            <div class="date" data-date="12-02-2012" data-date-format="dd-mm-yyyy">
                <div class="reminder-input">
                    <input class="datepicker-input" size="16" type="text" value="12-02-2012"/>
                    <input id="timepicker" data-template="modal" data-minute-step="1" data-modal-backdrop="true" type="text"/>
                </div>
            </div>
        """
        @datePick = $(@reminderDiv.lastChild).datepicker()
        @datePick.show()
        @datePick.on('changeDate', (e) =>
            nd = e.date
            date = @_currentDate
            date.setDate(nd.getDate())
            date.setMonth(nd.getMonth())
            date.setFullYear(nd.getFullYear())
        )

        @timePick = $(@reminderDiv.childNodes[2].firstElementChild.lastElementChild)
        @timePick.timepicker(
            minuteStep   : 1
            template     : 'modal'
            showSeconds  : true
            showMeridian : false
        )

        # listener for the title click
        reminderTitle = @reminderDiv.querySelector('.reminder-title')
        reminderTitle.addEventListener 'click', () =>
            @hotString.validate()


        # .timepicker().on('changeTime.timepicker', (e) ->
        #     console.info e.time
        #     t = e.time
        #     date = @_currentDate
        #     date.setHours(t.getDate())
        #     date.setMinutes(t.getMonth())
        #     date.setSeconds(t.getFullYear())
        # )

        @regexStore = {}
        @isVisible  = false

        auto  = document.createElement('div')
        auto.id = 'CNE_autocomplete'
        auto.className = 'CNE_autocomplete'
        auto.setAttribute('contentEditable','false')
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
            # {text:'contact' , type:'ttag', value:'contact' , mention:' (@)' }
            # {text:'reminder', type:'ttag', value:'reminder', mention:' (@@)'}
            {text:'todo'    , type:'ttag', value:'todo'                     }
            # {text:'tag'     , type:'ttag', value:'htag'    , mention:' (#)' }
            ])

        # @setItems( 'contact', [
        #     {text:'Frank @Rousseau' , type:'contact'             }
        #     {text:'Lucas Toulouse'  , type:'contact'             }
        #     {text:'Maxence Cote'    , type:'contact'             }
        #     {text:'Joseph Silvestre', type:'contact'             }
        #     {text:'Romain Foucault' , type:'contact'             }
        #     {text:'Zoé Bellot'      , type:'contact'             }
        #     ])

        # @setItems( 'htag', [
        #     {text:'Carte'              , type:'htag'}
        #     {text:'Factures'           , type:'htag'}
        #     {text:'Javascript'         , type:'htag'}
        #     {text:'Pérou 2012'         , type:'htag'}
        #     {text:'Présentation LyonJS', type:'htag'}
        #     {text:'Recettes cuisine'   , type:'htag'}
        #     ])

        return this


    ###*
     * Adds items to a type of suggestions
     * @param {String} type  'tTags', 'contact', 'htag'
     * @param {Object} items Object {text, type, [mention]}
    ###
    setItems : (type, items) ->
        # console.info ' setItems', items, type
        switch type
            when 'tTags'
                @tTags = items
                lines = @tTagsDiv
            when 'contact'
                @contacts = items
                lines = @contactsDiv
            when 'htag'
                @htags = items
                lines = @htagDiv
        for it in items
            lines.appendChild(@_createLine(it))

        return true


    ###*
     * Insert a suggestion line in the list of possible suggestions
     * @param  {Object} item The item which can be suggested.
     * @return {Object}      A ref to the created line.
    ###
    _createLine : (item) ->
        # console.info '_createLine', item

        line = document.createElement('LI')
        # line.contentEditable = false
        type = item.type
        switch type
            when 'ttag'
                line.className = 'SUGG_line_ttag'
            when 'contact'
                line.className = 'SUGG_line_contact'
            when 'htag'
                line.className = 'SUGG_line_htag'
        # if line.childNodes.length != 0
        #     line.innerHTML = ''

        t = item.text.split('')
        for c in t
            span = document.createElement('SPAN')
            # span.contentEditable = false
            span.textContent = c
            line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'SUGG_mention'
            line.appendChild(span)

        line.item = item
        item.line = line

        return line



    ###*
     * Show the suggestion list
     * @param  {Object} seg The segment of the editor to be positionned next to.
     * @param  {String} typedTxt   The string typed by the user (hotstring)
     * @param  {[type]} edLineDiv  The editor line div where the user is typing
    ###
    show : (seg,typedTxt) ->
        # modes = ['todo','contact','event','reminder','tag']
        edLineDiv = seg.parentElement
        @isVisible = true
        @update(typedTxt)
        @_position(seg)
        @container.appendChild(@el)



    setAllowedModes : (modes) ->
        @_modes = modes
        for ttag in @tTags
            ttag.isInMode = false
            for m in modes
                if ttag.value == m
                    ttag.isInMode = true
                    break

        # if modes[0] != @_currentMode
        #     return @setMode(modes[0])

        return true


    ###*
     * set the autocomplete popover to a mode : contact, htag, reminder.
     * @param {String} mode 'contact', 'htag', 'reminder'.
    ###
    setMode : (mode) ->

        @_unSelectLine()

        switch mode

            when 'ttag'
                @_currentMode = 'ttag'
                if !@tTagsDiv.parentNode
                    @el.appendChild(@tTagsDiv)
                if @htagDiv.parentNode
                    @el.removeChild(@htagDiv)
                if @contactsDiv.parentNode
                    @el.removeChild(@contactsDiv)
                if @reminderDiv.parentNode
                    @el.removeChild(@reminderDiv)

            when 'contact'
                @_currentMode = 'contact'
                if !@tTagsDiv.parentNode
                    @el.appendChild(@tTagsDiv)
                if @htagDiv.parentNode
                    @el.removeChild(@htagDiv)
                if !@contactsDiv.parentNode
                    @el.appendChild(@contactsDiv)
                if @reminderDiv.parentNode
                    @el.removeChild(@reminderDiv)

            when 'htag'
                @_currentMode = 'htag'
                if @tTagsDiv.parentNode
                    @el.removeChild(@tTagsDiv)
                if !@htagDiv.parentNode
                    @el.appendChild(@htagDiv)
                if @contactsDiv.parentNode
                    @el.removeChild(@contactsDiv)
                if @reminderDiv.parentNode
                    @el.removeChild(@reminderDiv)

            when 'reminder'
                now = new Date()
                @_currentDate = now
                @_initialDate = new Date()
                @datePick.datepicker('setValue', now)
                @timePick.timepicker('setTime', now.getHours()+':'+now.getMinutes()+':'+now.getSeconds())
                @_currentMode = 'reminder'
                if @tTagsDiv.parentNode
                    @el.removeChild(@tTagsDiv)
                if @htagDiv.parentNode
                    @el.removeChild(@htagDiv)
                if @contactsDiv.parentNode
                    @el.removeChild(@contactsDiv)
                if !@reminderDiv.parentNode
                    @el.appendChild(@reminderDiv)



    update : (typedTxt) ->

        if !@isVisible
            return

        nbrOfSuggestions = 0

        switch @_currentMode
            when 'ttag'
                for ttag in @tTags
                    if ttag.isInMode && @_shouldDisp(ttag,typedTxt)
                        nbrOfSuggestions += 1
                        ttag.line.style.display = 'block'
                    else
                        ttag.line.style.display = 'none'
                items = []
            when 'contact'
                # check the ttags to show
                for ttag in @tTags
                    if ttag.isInMode && @_shouldDisp(ttag,typedTxt)
                        nbrOfSuggestions += 1
                        ttag.line.style.display = 'block'
                    else
                        ttag.line.style.display = 'none'
                items = @contacts
            when 'htag'
                items = @htags
            when 'reminder'
                reg1 = /\+?(\d+)h(\d*)mn/i
                reg2 = /\+?(\d+)h/i
                reg3 = /\+?((\d+)d)?((\d+)h)?((\d*)mn)?/i
                regD  = /(\d+)d/i
                regH  = /(\d+)h/i
                regMn = /(\d+)mn/i
                # txt = typedTxt.slice(2)
                resReg1 = reg1.exec(typedTxt)
                resReg2 = reg2.exec(typedTxt)
                resReg3 = reg3.exec(typedTxt)
                resRegD  = regD.exec(typedTxt)
                resRegH  = regH.exec(typedTxt)
                resRegMn = regMn.exec(typedTxt)

                console.info resRegD
                if resRegMn or resRegH or resRegD
                    dd = dh = dmn = 0
                    if resRegD
                        dd  = parseInt(resRegD[1])  * 3600000 * 24
                    if resRegH
                        dh  = parseInt(resRegH[1])  * 3600000
                    if resRegMn
                        dmn = parseInt(resRegMn[1]) * 60000
                    @_currentDate.setTime(@_initialDate.getTime()+dd+dh+dmn)
                    now = @_currentDate
                    @datePick.datepicker('setValue', now)
                    @timePick.timepicker('setTime', now.getHours()+':'+now.getMinutes()+':'+now.getSeconds())
                return

        # check the items to show
        for it in items
            if @_shouldDisp(it,typedTxt)
                nbrOfSuggestions += 1
                it.line.style.display = 'block'
            else
                it.line.style.display = 'none'

        # sort items to show
        @_sortItems()

        @nbrOfSuggestions = nbrOfSuggestions

        return true



    _position : (span) ->
        # span = document.createElement('SPAN')
        # targetRange = currentSel.theoricalRange
        # targetRange.insertNode(span)
        @el.style.left = span.offsetLeft + 'px'
        @el.style.top  = span.offsetTop  + 17   + 'px'
        # parent = span.parentElement
        # parent.removeChild(span)
        span.parentElement.normalize()
        # currentSel.range.collapse(true)
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
        console.info '_updateLine'
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
        line = @_selectedLine
        if line
            line.classList.remove('SUGG_selected')
            @_selectedLine = null
        return line



    _removeLine : (line)->
        @el.removeChild(line)



    ###*
     * Hide auto complete and returns the current selected item, null if none.
     * @return {[type]} [description]
    ###
    hide : () ->
        if !@isVisible
            return false
        @container.removeChild(@el)
        @isVisible = false

        item = @getSelectedItem()

        return item



    getSelectedItem : () ->
        switch @_currentMode
            when 'ttag', 'contact'
                if @_selectedLine
                    item = @_selectedLine.item
                    @_unSelectLine()
                else
                    item = null
                    @_selectedLine = null
            when 'htag'
                if @_selectedLine && @_selectedLine.item.type == 'htag'
                    item = @_selectedLine.item
                    @_unSelectLine()
                else
                    item = null
                    @_selectedLine = null
            when 'reminder'
                date = @_currentDate
                item = text:date, type:'reminder', value:@_currentDate

        return item



    _shouldDisp : (item,typedTxt) ->
        if @regexStore[typedTxt]
            reg = @regexStore[typedTxt]
        else
            regText = typedTxt.replace(/\W/g,'').split('').join('[\\w ]*')
            reg = new RegExp(regText, 'i')
            @regexStore[typedTxt] = reg
        if item.text.match(reg)
            typedCar = typedTxt.toLowerCase().split('')
            c = typedCar.shift()
            spans = item.line.childNodes
            i = 0
            l = spans.length
            if item.line.lastChild.className == 'SUGG_mention'
                l -= 1
            while i < l
                s = spans[i]
                if s.textContent.toLowerCase() == c
                    s.className = 'b'
                    c = typedCar.shift()
                    if c
                        i += 1
                    else
                        i +=1
                else
                    s.className = ''
                    i += 1
            return true
        else
            return false



    ###*
     * select previous suggestion in auto complete. Behaviour depends on the
     * mode (reminder is different from contact for instance)
    ###
    up : () ->

        if  @nbrOfSuggestions == 0
            return

        if !@_selectedLine
            @_selectedLine = @el.lastChild.lastChild

        else
            line = @_unSelectLine()
            prev = line.previousSibling
            if prev
                @_selectedLine = prev
            else
                if line.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.lastChild
                else
                    @_selectedLine = @el.firstChild.lastChild

        if @_selectedLine.style.display == 'none'
            @up()
        else
            @_selectLine()

        return true


    ###*
     * select next suggestion in auto complete. Behaviour depends on the mode
     * (reminder is different from contact for instance)
    ###
    down : () ->

        if  @nbrOfSuggestions == 0
            return

        if !@_selectedLine
            @_selectedLine = @el.firstChild.firstChild

        else
            line = @_unSelectLine()
            next = line.nextSibling
            if next
                @_selectedLine = next
            else
                if line.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.firstChild
                else
                    @_selectedLine = @el.firstChild.firstChild

        if @_selectedLine.style.display == 'none'
            @down()
        else
            @_selectLine()



    val : () ->
        return @_selectedLine.item



    isInTTags : (text) ->
        for tag in @tTags
            if text == tag.text
                return tag
        return false



exports.AutoComplete = AutoComplete