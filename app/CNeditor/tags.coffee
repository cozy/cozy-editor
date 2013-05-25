
selection = require('./selection').selection

###*
 * Helpers for Tags
 * Tag = a segment with a .dataset.type (reminder, a button of a task, a
 * contact ...)
###

module.exports = class Tags

    constructor : () ->
        @_tagList = []
        @_areTagsEditable = true
        window.taglist = @_tagList

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

    remove : (seg) ->
        @_tagList = _.without(@_tagList, seg)

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
        if startSeg != endSeg
            seg = startSeg.nextSibling
            while seg != endSeg
                # if end of line, go to next line
                if seg.nodeName == 'BR'
                    seg = seg.parentElement.nextSibling.firstChild
                    if seg == endSeg
                        break
                # if a tag, remove it
                if seg.dataset.type
                    @_tagList = _.without(@_tagList, seg)
                seg = seg.nextSibling

        return true
