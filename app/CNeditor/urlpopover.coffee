selection = require './selection'

###* -----------------------------------------------------------------------
 * initialise the popover during the editor initialization.
###
module.exports = class UrlPopover

    constructor : (@editor) ->

        @isOn = false

        @el  = document.createElement('div')
        @el.id = 'CNE_urlPopover'
        @el.className = 'CNE_urlpop'
        @el.contentEditable = false
        @el.innerHTML =
            """
            <span class="CNE_urlpop_head">Link</span>
            <span  class="CNE_urlpop_shortcuts">(Ctrl+K)</span>
            <div class="CNE_urlpop-content">
                <a target="_blank">Open link <span class="CNE_urlpop_shortcuts">
                    (Ctrl+click)</span></a></br>
                <span>url</span><input type="text"></br>
                <span>Text</span><input type="text"></br>
                <button class="btn">ok</button>
                <button class="btn">Cancel</button>
                <button class="btn">Delete</button>
            </div>
            """
        @el.titleElt = @el.firstChild
        @el.link = @el.getElementsByTagName('A')[0]

        [btnOK, btnCancel, btnDelete] = @el.querySelectorAll('button')
        btnOK.addEventListener     'click', @validate
        btnCancel.addEventListener 'click', (e) =>
            e.stopPropagation()
            @cancel false
        btnDelete.addEventListener 'click', =>
            @el.urlInput.value = ''
            @validate()

        [urlInput,textInput] = @el.querySelectorAll('input')
        @el.urlInput = urlInput
        @el.textInput = textInput
        @el.addEventListener 'keypress', (e) =>
            if e.keyCode == 13
                @validate()
                e.stopPropagation()
            else if e.keyCode == 27
                @cancel false

            return false

        @editor.editorBody.addEventListener 'mouseup', @clickOut

        return true


    ###* -----------------------------------------------------------------------
     * Show, positionate and initialise the popover for link edition.
     * @param  {array} segments  An array with the segments of
     *                           the link [<a>,...<a>]. Must be created even if
     *                           it is a creation in order to put a background
     *                           on the segment where the link will be.
     * @param  {boolean} isLinkCreation True is it is a creation. In this case,
     *                                  if the process is canceled, the initial
     *                                  state without link will be restored.
    ###
    show : (segments, isLinkCreation) ->

        # Disable the editor to prevent actions when popover is on
        @editor.disable()

        @isOn = true
        @isLinkCreation = isLinkCreation # save the flag

        # save initial selection range to restore it on close
        @el.initialSelRg = @editor.currentSel.theoricalRange.cloneRange()

        # save segments array
        @segments = segments

        # positionnate the popover
        seg = segments[0]
        @el.style.left = seg.offsetLeft + 'px'
        @el.style.top = seg.offsetTop + 20 + 'px'

        # update the inputs fields of popover
        href = seg.href
        if href == '' or href == 'http:///'
            href = 'http://'
        @el.urlInput.value = href
        txt = ''
        txt += seg.textContent for seg in segments
        @el.textInput.value = txt
        @el.initialTxt = txt

        if isLinkCreation
            @el.titleElt.textContent = 'Create Link'
            @el.link.style.display = 'none'
        else
            @el.titleElt.textContent = 'Edit Link'
            @el.link.style.display = 'inline-block'
            @el.link.href = href

        # Insert the popover
        seg.parentElement.parentElement.appendChild(@el)

        # select and put focus in the popover
        @el.urlInput.select()
        @el.urlInput.focus()

        # colorize the concerned segments.
        for seg in segments
            # seg.style.backgroundColor = '#dddddd'
            seg.classList.add('CNE_url_in_edition')

        return true


    ###* -----------------------------------------------------------------------
     * The callback for a click outside the popover
    ###
    clickOut : (e) =>
        elt = e.target

        # find @el in parents
        while elt isnt @el and elt isnt @editor.editorBody
            elt = elt.parentNode

        if elt isnt @el
            @cancel true

    ###* -----------------------------------------------------------------------
     * Close the popover and revert modifications if isLinkCreation == true
     * @param  {boolean} doNotRestoreOginalSel If true, lets the caret at its
     *                                         position (used when you click
     *                                         outside url popover in order not
     *                                         to loose the new selection)
    ###
    cancel : (doNotRestoreOginalSel) =>

        return unless @isOn

        # remove popover
        @el.parentElement.removeChild @el
        @isOn = false

        # remove the "selected style" of the segments
        seg.classList.remove 'CNE_url_in_edition' for seg in @segments

        # case of a link creation called and cancelled : a segment for the link
        # to creat has already been added in order to show the selection when
        # popover is visible. As it is canceled, we undo in order to remove this
        # link.
        if @isLinkCreation
            s0 = @segments[0]
            s1 = @segments[@segments.length-1]
            bp1 =
                cont   : s0
                offset : 0
            bp2 =
                cont   : s1
                offset : s1.childNodes.length
            bps = [bp1,bp2]
            selection.normalizeBPs(bps)
            lineDiv = selection._getLineDiv(s0)
            @editor._applyAhrefToSegments(s0, s1 , bps, false, '')
            @editor._fusionSimilarSegments(lineDiv,bps)
            if !doNotRestoreOginalSel
                @editor.setSelectionBp(bp1, bp2)

        else if !doNotRestoreOginalSel
            sel = @editor.getEditorSelection()
            sel.removeAllRanges()
            sel.addRange @el.initialSelRg

        # restore editor enabled
        @editor.setFocus()
        @editor.enable()

        return true


    ###* -----------------------------------------------------------------------
     * Close the popover and applies modifications to the link.
    ###
    validate : (event) =>

        event.stopPropagation() if event

        # 1- in case of a link creation and the user validated an empty url, just
        # cancel the link creation
        if @el.urlInput.value == '' && @isLinkCreation
            return @cancel false

        # 2- remove background of selection and hide popover
        @el.parentElement.removeChild @el
        @isOn = false

        seg.classList.remove('CNE_url_in_edition') for seg in @segments

        # 3- in case of a link creation, addhistory has already be done, but it
        # must be done if it is not a link creation.
        if !@isLinkCreation
            sel = @editor.getEditorSelection()
            sel.removeAllRanges()
            sel.addRange @el.initialSelRg # otherwise addhistory will not work
            @editor._history.addStep()

        # 4- keep a ref to the modified line
        lineDiv  = @segments[0].parentElement

        # 5- case of a deletion of the urlInput value => 'remove the link'
        if @el.urlInput.value == ''
            l = @segments.length
            bp1 =
                cont : @segments[0].firstChild
                offset : 0
            bp2 =
                cont   : @segments[l-1].firstChild
                offset : @segments[l-1].firstChild.length
            bps = [bp1,bp2]
            @editor._applyAhrefToSegments(@segments[0], @segments[l-1], bps, false, '')
            # fusion similar segments if any
            @editor._fusionSimilarSegments(lineDiv, bps)
            # Position selection
            rg = document.createRange()
            bp1 = bps[0]
            bp2 = bps[1]
            rg.setStart(bp1.cont, bp1.offset)
            rg.setEnd(  bp2.cont, bp2.offset)
            sel = @editor.getEditorSelection()
            sel.removeAllRanges()
            sel.addRange(rg)
            @editor.setFocus()
            # restore editor enabled
            @editor.enable()
            # warn that a change occured
            @editor.editorTarget$.trigger jQuery.Event('onChange')
            # stack Task modifications :
            # if lineDiv.dataset.type == 'task'
            #     @editor._stackTaskChange(lineDiv.task,'modified')
            return true

        # 6- case if only href is changed but not the text
        else if @el.initialTxt == @el.textInput.value
            seg.href = @el.urlInput.value for seg in @segments
            lastSeg = seg

        # 7- case if the text of the link is modified : we concatenate
        # all segments
        else
            seg = @segments[0]
            seg.href = @el.urlInput.value
            seg.textContent = @el.textInput.value
            parent = seg.parentNode
            for i in [1..@segments.length-1] by 1
                seg = @segments[i]
                parent.removeChild(seg)
            lastSeg = @segments[0]

        # 8- fusion similar segments if any
        i = selection.getSegmentIndex(lastSeg)
        i = i[1]
        bp = selection.normalizeBP(lineDiv, i+1)
        @editor._fusionSimilarSegments(lineDiv, [bp])

        # 9- manage selection, find a space after url or add it and move bp
        bp = @insertSpaceAfterUrl(selection.getNestedSegment(bp.cont))
        @editor._setCaret(bp.cont,bp.offset)
        @editor.setFocus()

        # 10- restore editor enabled
        @editor.enable()

        # 11- warn that a change occured
        @editor.editorTarget$.trigger jQuery.Event('onChange')

        # 12- stack Task modifications :
        if lineDiv.dataset.type == 'task'
            @editor._stackTaskChange(lineDiv.task,'modified')


    ###*
     * returns a break point, collapsed after a space caracter immediately
     * following a given segment. A segment will we inserted if required.
     * @param  {[type]} seg [description]
     * @return {Object}     {cont,offset} : the break point
    ###
    insertSpaceAfterUrl : (seg) ->
        nextSeg = seg.nextSibling
        if nextSeg.nodeName == 'BR'
            span = @editor._insertSegmentAfterSeg(seg)
            bp = cont:span.firstChild, offset:1
        else
            index = selection.getSegmentIndex(seg)[1] + 1
            bp = selection.normalizeBP(seg.parentElement, index, true)
            txtNode = bp.cont
            # c1 = txtNode.textContent[0]
            # if c1 != ' ' and c1 != '\u00a0'
            #     txtNode.textContent = '\u00a0' + txtNode.textContent
            # bp.offset = 1
            bp.offset = 0
        return bp