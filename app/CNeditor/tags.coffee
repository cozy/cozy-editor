selection = require('./selection')
ContactPopover = require('./contactpopover')

###*
 * Helpers for Tags
 * Tag = a segment with a .dataset.type (reminder, a button of a task, a
 * contact ...)
###

module.exports = class Tags

    constructor : (@editor, @models) ->
        @_tagList = []
        @oldList = null
        @_areTagsEditable = true
        window.taglist = @_tagList

        @contactPopover = new ContactPopover()

        @models.contactCollection.on
            'change:name' : @_updateContactSegment
            'destroy'     : @_removeContactSegment

        @models.alarmCollection.on
            'change:trigg': @_updateReminderSegment
            'destroy'     : @_removeReminderSegment

    ###*
     * The selection within tags is difficult. The idea is to have selection
     * whether in a tag, or fully outside any tag. To deal the different pb,
     * here is the logic choosen :
     * Tags are usually "editable" (= contentEditable = true) except :
     *   - when shift key is pressed (keydown) outside a tag : then turn all
     *     tags un-editable. If the user modify the selection with keyboard
     *     (shift + arrow or alike) then the browser will not let selection go
     *     into a tag.
     *   - when mousedown outside of a tag : then turn all tag un-editable so
     *     that selection can not end in one of them.
     *   - when mouseup or keyup : let all tags be editable agin and check if
     *     the selection has an end in a tag and not the other (possible if the
     *     change of the selection started within a tag in edition), then modify
     *     the selection to be fully in the tag.
     *
    ###
    setTagEditable : () ->
        # console.info 'set tags EDITABLE'
        if !@_areTagsEditable
            for tag in @_tagList
                tag.contentEditable = true
            @_areTagsEditable = true


    setTagUnEditable : () ->
        # console.info 'set tags UN-EDITABLE'
        if @_areTagsEditable
            for tag in @_tagList
                tag.contentEditable = false
            @_areTagsEditable = false


    create : (type, seg) ->
        seg.classList.remove 'CNE_hot_string'
        seg.contentEditable = @_areTagsEditable

        switch type
            when 'contact'
                seg.classList.add 'CNE_contact'
                seg.dataset.type = 'contact'
                @handle seg

            when 'reminder'
                seg.classList.add 'CNE_reminder'
                seg.dataset.type = 'reminder'
                date = Date.create(seg.dataset.value)
                alarm = new @models.Alarm
                    id:          seg.dataset.id or null
                    trigg:       date.format @models.Alarm.dateFormat

                @models.alarmCollection.add alarm
                @handle seg

                alarm.save()
                .done =>
                    seg.dataset.id = alarm.id
                .fail (jqXHR) =>
                    console.log jqXHR
                    console.log 'failed to save CNE_reminder'
                    @remove seg

    empty : (isFullReplaceContent) =>
        @isFullReplaceContent = isFullReplaceContent
        @oldList = _.clone @_tagList
        @_tagList = []

    handle : (seg, norefresh) =>
        @_tagList.push seg

        # @refresh seg unless norefresh

    refreshAll : ->

        iz = (a) -> (b) -> a.dataset.id is b.dataset.id

        for oldseg in (@oldList or [])
            unless @_tagList.some(iz oldseg)
                # the segment have been deleted since empty
                if oldseg.dataset.type is 'reminder'
                    @remove oldseg

        if @oldList and not @isFullReplaceContent
            for newseg in @_tagList
                unless @oldList.some(iz newseg)
                    # the segment have been created since empty (reDo)
                    if newseg.dataset.type is 'reminder'
                        # recreate a new similar alarm
                        delete newseg.dataset.id
                        date = Date.create(newseg.dataset.value)
                        alarm = new @models.Alarm
                            trigg:       date.format @models.Alarm.dateFormat

                        @models.alarmCollection.add alarm
                        alarm.save()
                        .done =>
                            newseg.dataset.id = alarm.id
                        .fail (jqXHR) =>
                            console.log jqXHR
                            console.log 'failed to save CNE_reminder'
                            @remove seg


        @refresh seg for seg in @_tagList

    refresh : (seg) ->
        switch seg.dataset.type
            when 'reminder'
                model = @models.alarmCollection.get seg.dataset.id
                if model
                    value = Date.create(model.get('trigg')).format()
                    seg.textContent = value
                else
                    # model not in the collection, probably a load
                    model = new @models.Alarm(id: seg.dataset.id)
                    model.fetch().fail =>
                        @models.alarmCollection.remove model
                        @remove seg
                    @models.alarmCollection.add model

            when 'contact'
                model = @models.contactCollection.get seg.dataset.id
                seg.textContent = model.get 'name'


    remove : (seg) ->
        console.log 'Tags.remove', seg
        @_tagList = _.without(@_tagList, seg)

        switch seg.dataset.type
            when 'reminder'
                seg.textContent = '@@' + seg.textContent
                model = @models.alarmCollection.get(seg.dataset.id)
                model.destroy() if model
            when 'contact'
                seg.textContent = '@' + seg.textContent

        seg.classList.remove 'CNE_reminder'
        seg.classList.remove 'CNE_contact'

        delete seg.dataset.id
        delete seg.dataset.type
        delete seg.dataset.value

    ###*
     * Find and removes all tags within a range (normalize it for precaution).
     * @param  {Range} rg The range in which the tags to remove are.
    ###
    removeFromRange : (rg) ->
        startSeg = selection.getSegment(rg.startContainer,0)
        endSeg   = selection.getSegment(rg.endContainer  ,0)
        console.info '_tagList at beginning', @_tagList

        # if equal, means we are inside a tag or oustide, no tag will be
        # deleted
        return null if startSeg is endSeg

        seg = startSeg.nextSibling
        while seg != endSeg
            # if end of line, go to next line
            if seg.nodeName == 'BR'
                seg = seg.parentElement.nextSibling.firstChild
                if seg == endSeg
                    break
            # if a tag, remove it
            @remove seg if seg.dataset.type
            seg = seg.nextSibling

        return true


    clickCb: (e) ->

        oldcontactseg = @contactPopover.hide()

        if e.target.dataset.type is 'contact' and e.target isnt oldcontactseg
            model = @models.contactCollection.get e.target.dataset.id
            @contactPopover.show e.target, model


    _removeContactSegment: (model) =>
        for seg in @_tagList
            if seg.dataset.type is 'contact' and seg.dataset.id is model.id
                @remove seg

    _updateContactSegment: (model) =>
        for seg in @_tagList
            if seg.dataset.type is 'contact' and seg.dataset.id is model.id
                seg.textContent = model.get 'name'

    _removeReminderSegment: (model) =>
        for seg in @_tagList
            if seg.dataset.type is 'reminder' and seg.dataset.id is model.id
                @remove seg

    _updateReminderSegment: (model) =>
        for seg in @_tagList
            if seg.dataset.type is 'reminder' and seg.dataset.id is model.id
                value = Date.create(model.get('trigg')).format()
                seg.textContent = value
