
µ = {}

### ------------------------------------------------------------------------
# UTILITY FUNCTIONS
# used to set ranges and help normalize selection
#
# parameters: elt  :  a dom object with only textNode children
#
# note: with google chrome, it seems that non visible elements
#       cannot be selected with rangy (that's where 'blank' comes in)
###


###*
 * Called only once from the editor - TODO : role to be verified
###
µ.cleanSelection = (startLine, endLine, range) ->
    if startLine is null
        startLine = endLine
        endLine   = endLine.lineNext
        µ.putStartOnStart range, startLine.line$[0].firstElementChild
        endLine.line$.prepend '<span></span>'
        µ.putEndOnStart range, endLine.line$[0].firstElementChild
    else
        startNode = startLine.line$[0].lastElementChild.previousElementSibling
        endNode   = endLine.line$[0].lastElementChild.previousElementSibling
        range.setStartAfter startNode, 0
        range.setEndAfter endNode, 0

µ.selectAll = (editor) ->
    range = document.createRange()
    range.setStartBefore(editor.linesDiv.firstChild)
    range.setEndAfter(editor.linesDiv.lastChild)
    µ.normalize(range)
    sel = editor.getEditorSelection()
    sel.removeAllRanges()
    sel.addRange(range)


###*
 * Called only once from the editor - TODO : role to be verified
###
µ.cloneEndFragment = (range, endLine) ->
    range4fragment = rangy.createRangyRange()
    range4fragment.setStart range.endContainer, range.endOffset
    range4fragment.setEndAfter endLine.line$[0].lastChild
    range4fragment.cloneContents()


### ------------------------------------------------------------------------
#  normalize(range)
#
#  Modify 'range' containers and offsets so it represent a clean selection
#  that starts and ends inside a textNode.
#
#  Set the flag isEmptyLine to true if an empty line is being normalized
#  so further suppr ~ backspace work properly.
#
#  All possible breakpoints :
    - <span>|<nodeText>|Text |node content|</nodeText>|<any>...</nodeText>|</span>
           BP1        BP2   BP3          BP4         BP5             BP6

    - <div>|<span>...</span>|<any>...</span>|</br>|</div>
          BP7              BP8             BP9    BP10

    - <body>|<div>...</div>|<div>...</div>|</body>
           BP11           BP12           BP13


    BP1 : <span>|<nodeText>

        |     test    |               action              |
        |-------------|-----------------------------------|
        | cont = span | if cont.length = 0                |
        | offset = 0  | * create nodeText                 |
        |             | * BP2 => BP2                      |
        |             | else if cont.child(0) = nodeText  |
        |             | * BP2 => BP2                      |
        |             | else if cont.child(0) != nodeText |
        |             | * error                           |

    BP2 : <nodeText>|Text node content</nodeText>

        |       test      |  action |
        |-----------------|---------|
        | cont = nodeText | nothing |
        | offset = 0      |         |

    BP3 : <nodeText>Text |node content</nodeText>

        |         test         |  action |
        |----------------------|---------|
        | cont = nodeText      | nothing |
        | 0<offset<cont.length |         |

    BP4 : <nodeText>Text node content|</nodeText>

        |         test         |  action |
        |----------------------|---------|
        | cont = nodeText      | nothing |
        | offset = cont.length |         |

    BP5 & BP6 : </nodeText>|<any>
        |               test              |            action           |
        |---------------------------------|-----------------------------|
        | cont != nodeText                | bpEnd(cont.child(offset-1)) |
        | offset > 0                      |                             |
        | cont.child(offset-1) = nodeText |                             |

    BP7 : <div>|<span>...
        |    test    |          action          |
        |------------|--------------------------|
        | cont = div | if cont.length = 0       |
        | offset = 0 | * error                  |
        |            | else                     |
        |            | bpStart(cont.firstChild) |

    BP8 & BP9 : ...</span>|<any>...
        |             test            |            action           |
        |-----------------------------|-----------------------------|
        | cont != nodeText            | bpEnd(cont.child(offset-1)) |
        | offset > 0                  |                             |
        | cont.child(offset-1) = span |                             |

    BP10 : </br>|</div>
        |            test           |            action           |
        |---------------------------|-----------------------------|
        | cont != nodeText          | bpEnd(cont.child(offset-2)) |
        | offset > 0                |                             |
        | offset=cont.length        |                             |
        | cont.child(offset-1) = br |                             |

    BP11 : <body>|<div>...
        |     test    |          action          |
        |-------------|--------------------------|
        | cont = body | bpStart(cont.firstChild) |
        | offset = 0  |                          |

    BP12 : </div>|<any>
        |            test            |            action           |
        |----------------------------|-----------------------------|
        | cont != nodeText           | bpEnd(cont.child(offset-1)) |
        | offset > 0                 |                             |
        | offset=cont.length         |                             |
        | cont.child(offset-1) = div |                             |


    BP13 : ...</div>|</body>
        |         test         |         action        |
        |----------------------|-----------------------|
        | cont = body          | bpEnd(cont.lastChild) |
        | offset = cont.length |                       |
###
µ.normalize = (rg, preferNext) ->
    isCollapsed = rg.collapsed
    newStartBP = µ.normalizeBP(rg.startContainer, rg.startOffset, preferNext)
    rg.setStart(newStartBP.cont,newStartBP.offset)
    if isCollapsed
        rg.collapse(true)
        newEndBP = newStartBP
    else
        newEndBP = µ.normalizeBP(rg.endContainer, rg.endOffset, preferNext)
        rg.setEnd(newEndBP.cont,newEndBP.offset)

    return [newStartBP, newEndBP]


###*
 * Returns a break point in the most pertinent text node given a random bp.
 * @param  {element} cont   the container of the break point
 * @param  {number} offset offset of the break point
 * @param  {boolean} preferNext [optional] if true, in case BP8, we will choose
 *                              to go in next sibling - if it exists - rather
 *                              than in the previous one.
 * @return {object} the suggested break point : {cont:newCont,offset:newOffset}
###
µ.normalizeBP = (cont, offset, preferNext) ->
    if cont.nodeName == '#text'
        # nothing to do
        res = {cont:cont,offset:offset}

    else if cont.nodeName in ['SPAN','A']
        # search a text node before and put bp in it
        # if none, search a text node after and put bp in it
        # if none create one and put bp in it
        if offset > 0
            newCont   = cont.childNodes[offset-1]
            newOffset = newCont.length
        else if cont.childNodes.length > 0
            newCont   = cont.firstChild
            newOffset = 0
        else
            newCont   = document.createTextNode('')
            cont.appendChild(newCont)
            newOffset = 0

    else if cont.nodeName == 'DIV' and cont.id != "editor-lines"
        # <div>|<span>...</span>|<any>...</span>|</br>|</div>
        #     BP7              BP8             BP9    BP10
        # if offset = 0 put bp in 1st child
        if offset == 0
            if µ.isSegment(cont.firstChild)
                res = µ.normalizeBP(cont.firstChild,0)
            else
                res = µ.normalizeBP(cont.firstChild.nextSibling,0)
        # if the 1st element is not a segment (a todobtn for instance)
        else if offset == 1 && !µ.isSegment(cont.firstChild)
            res = µ.normalizeBP(cont.firstChild.nextSibling,0)
        # if offset in middle, put bp at the end of previous element or at the
        # beginning of next depending on preferNext value.
        else if offset < cont.children.length-1
            if preferNext
                newCont   = cont.children[offset]
                if newCont.nodeName == 'BR'
                    newCont   = cont.children[offset-1]
                newOffset = 0
                res       = µ.normalizeBP(newCont, newOffset)
            else
                newCont   = cont.children[offset-1]
                newOffset = newCont.childNodes.length
                res       = µ.normalizeBP(newCont, newOffset)
        # if offset before or after </br> put bp at the end of element
        # before </br>
        else
            newCont   = cont.children[cont.children.length-2]
            newOffset = newCont.childNodes.length
            res       = µ.normalizeBP(newCont, newOffset)

    else if cont.nodeName ==  'DIV' and cont.id == "editor-lines"
        # if offset==0 put bp at begin of first node
        if offset == 0
            newCont   = cont.firstChild
            newOffset = 0
            res       = µ.normalizeBP(newCont, newOffset)
        # if bp is at end of container, put bp at end of last node
        else if offset == cont.childNodes.length
            newCont   = cont.lastChild
            newOffset = newCont.childNodes.length
            res       = µ.normalizeBP(newCont, newOffset)
        # if bp is in the middle of container, put bp at end of the node
        # before current bp
        else
            newCont   = cont.children[offset-1]
            newOffset = newCont.childNodes.length
            res       = µ.normalizeBP(newCont, newOffset)

    else if cont.nodeName ==  'BR'
            newCont   = cont.previousSibling
            newOffset = newCont.childNodes.length
            res       = µ.normalizeBP(newCont, newOffset)

    if !res
        res = {cont:newCont,offset:newOffset}

    return res


###*
 * Normalize an array of breakpoints.
 * @param  {Array} bps   An array of break points to normalize
 * @param  {boolean} preferNext [optional] if true, in case BP8, we will choose
 *                              to go in next sibling - if it exists - rather
 *                              than in the previous one.
 * @return {Array} A ref to the array of normalized bp.
###
µ.normalizeBPs = (bps, preferNext) ->
    for bp in bps
        newBp     = µ.normalizeBP(bp.cont,bp.offset,preferNext)
        bp.cont   = newBp.cont
        bp.offset = newBp.offset
    return bps


###*
 * return the div corresponding to an element inside a line and tells wheter
 * the breabk point is at the end or at the beginning of the line
 * @param  {element} cont   the container of the break point
 * @param  {number} offset offset of the break point
 * @return {object}        {div[element], isStart[bool], isEnd[bool]}
###
µ.getLineDivIsStartIsEnd = (cont, offset)->


    # 1- Check offset position in its container. If we are already in the line
    # div, directly return the result.
    if (       cont.nodeName == 'DIV'                                          \
           and cont.id?                                                        \
           and cont.id.substr(0,5) == 'CNID_'  )

        if cont.textContent == '' # case : <div><xx></xx>...</br></div>
            return div:cont, isStart:true, isEnd:true

        isStart = (offset==0)
        n       = cont.childNodes.length
        isEnd   = (offset==n) or (offset==n-1)
        return div:cont, isStart:isStart, isEnd:isEnd

    else
        if cont.length?  # case of cont is a text node
            isStart = (offset==0)
            isEnd   = (offset==cont.length)
        else             # we are in an element but not in the line div
            isStart = (offset==0)
            isEnd   = (offset==cont.childNodes.length)

    # 2- walk throught each parent of the container until reaching the div.
    # Check the index of each parent to know if it is at the end or beginning.

    parent  = cont.parentNode
    while !(parent.nodeName == 'DIV'              \
            and parent.id?                        \
            and parent.id.substr(0,5) == 'CNID_') \
          and parent.parentNode != null
        index = µ.getNodeIndex(cont)
        isStart = isStart && (index==0)
        isEnd = isEnd && (index==parent.childNodes.length-1)
        cont = parent
        parent = parent.parentNode

    # 3- parent is the line div, check isStart isEnd
    if parent.textContent == '' # case : <div><xx></xx>...</br></div>
        return div:parent, isStart:true, isEnd:true
    [segmentI,nodeI] = µ.getSegmentIndex(cont)
    n     = parent.childNodes.length
    isStart = isStart && (segmentI==0)
    isEnd   = isEnd && ((nodeI==n-1) or (nodeI==n-2))

    return div:parent, isStart:isStart, isEnd:isEnd

    # # 1- walk trew each parent of the container until reaching the div.
    # # On each parent check if breakpoint is still at the end or start
    # while !(parent.nodeName == 'DIV'              \
    #         and parent.id?                        \
    #         and parent.id.substr(0,5) == 'CNID_') \
    #       and parent.parentNode != null

    #     # 1.1 check isStart isEnd
    #     isStart = isStart && (offset==0)

    #     # 1.2 check isEnd
    #     if parent.length?
    #         isEnd = isEnd && (offset==parent.length)
    #     else if parent.lastChild == null
    #         isEnd = true
    #     else # we are in a non empty element but not in the line div
    #         isEnd = isEnd && (offset==parent.childNodes.length)

    #     # 1.3 prepare next loop :
    #     # 1.3.1 find offset of the current element among its siblings
    #     offset = µ.getNodeIndex(parent)
    #     # 1.3.2 go up to the parent level
    #     parent = parent.parentNode

    #     # if parent.previousSibling == null
    #     #     offset = 0
    #     # else if parent.nextSibling == null
    #     #     offset = parent.parentNode.childNodes.length - 1
    #     # else if parent.nextSibling.nodeName == 'BR'
    #     #     offset = parent.parentNode.childNodes.length - 2
    #     # else
    #     #     # we are not at the beginning nor the end, nor before a br : then we
    #     #     # can set 1 to the parent offset because it is not important to know
    #     #     # the exact offset in this case.
    #     #     offset = 1

    # # 2 check isStart isEnd at the line div level
    # nodesNum = parent.childNodes.length
    # isStart = isStart && (offset==0)
    # isEnd   = isEnd && (offset==nodesNum or offset==nodesNum-1)
    # if parent.textContent == '' # case : <div><xx></xx>...</br></div>
    #     isStart = true
    #     isEnd   = true

    # return div:parent, isStart:isStart, isEnd:isEnd


# BJA : usage qu'interne, à voir.
µ.putStartOnStart = (range, elt) ->
    if elt?.firstChild?
        offset = elt.firstChild.textContent.length
        if offset == 0 then elt.firstChild.data = " "
        range.setStart elt.firstChild, 0
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart blank, 0


# BJA : usage qu'interne, à voir.
µ.putEndOnStart = (range, elt) ->
    if elt?.firstChild?
        offset = elt.firstChild.textContent.length
        elt.firstChild.data = " " if offset == 0
        range.setEnd(elt.firstChild, 0)
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setEnd(blank, 0)



###*
 * Returns the DIV of the line where the break point is.
 * @param  {element} cont   The contener of the break point
 * @param  {number} offset Offset of the break point.
 * @return {element}        The DIV of the line where the break point is.
###
µ.getLineDiv = (cont,offset) ->
    if cont.nodeName == 'DIV'
        if cont.id == 'editor-lines'
            startDiv = cont.children[offset]
        else
            startDiv = µ._getLineDiv(cont)
    else
        startDiv = µ._getLineDiv(cont)
    return startDiv

# Get line that contains given element.
# Prerequisite : elt must be in a div of a line.
µ._getLineDiv = (elt)->
    parent = elt
    until (parent.nodeName == 'DIV'                                            \
            and parent.id?                                                     \
            and (    parent.id.substr(0,5) == 'CNID_'                          \
                  or parent.id == 'editor-lines'       )                       \
            )                                                                  \
          && parent.parentNode != null
        parent = parent.parentNode
    return parent

###*
 * Returns the segment (span or a or lineDiv) of the line where the break
 * point is. If the break point is not in a segment, ie in the line div or even
 * in editor-lines, then it is the line div that will be returned.
 * @param  {element} cont   The contener of the break point
 * @param  {number} offset  Offset of the break point. Optional if cont is a
 *                          text node
 * @return {element}        The DIV of the line where the break point is.
###
µ.getSegment = (cont,offset) ->
    if cont.nodeName == 'DIV'
        if cont.id == 'editor-lines'
            startDiv = cont.children[Math.min(offset, cont.children.length-1)]
        else if cont.id? and cont.id.substr(0,5) == 'CNID_'
            startDiv = cont
        else
            startDiv = µ.getNestedSegment(cont)
    else
        startDiv = µ.getNestedSegment(cont)
    return startDiv


# Get segment that contains given element.
# Prerequisite : elt must be in a segment of a line.
µ.getNestedSegment = (elt)->
    parent = elt.parentNode
    until (parent.nodeName == 'DIV'                                            \
            and parent.id?                                                     \
            and (    parent.id.substr(0,5) == 'CNID_'                          \
                  or parent.id == 'editor-lines'       )                       \
            )                                                                  \
          && parent.parentNode != null
        elt = parent
        parent = elt.parentNode
    return elt


µ.isSegment = (segment) ->
    return segment.nodeName != 'BR'                                            \
           and !segment.classList.contains('CNE_task_btn')


µ.getNextSegment = (seg) ->
    seg = seg.nextSibling
    while seg and !µ.isSegment(seg)
        seg = seg.nextSibling
    return seg



###*
 * returns previous segment if one, none otherwise
 * @param  {Element} seg The source segment
 * @return {element}     Returns previous segment if one, none otherwise
###
µ.getPrevSegment = (seg) ->
    seg = seg.previousSibling
    while seg and !µ.isSegment(seg)
        seg = seg.previousSibling
    return seg



###*
 * Returns the normalized break point at the end of the previous segment of the
 * segment of an element.
 * @param {[type]} elmt [description]
###
µ.setBpPreviousSegEnd = (elmt) ->
    seg   = µ.getNestedSegment(elmt)
    index = µ.getNodeIndex(seg)
    # by default normalizeBP will return a bp at the end of previous segment
    return bp = µ.normalizeBP(seg.parentNode, index)


###*
 * Returns the normalized break point at the start of the next segment of the
 * segment of an element.
 * @param {[type]} elmt [description]
###
µ.setBpNextSegEnd = (elmt) ->
    seg   = µ.getNestedSegment(elmt)
    index = µ.getNodeIndex(seg) + 1
    # by default normalizeBP will return a bp at the end of previous segment
    return bp = µ.normalizeBP(seg.parentNode, index, true)

###*
 * Returns [segmentIndex,nodeIndex]
 * @param  {Element} segment The segment to find it's indexes
 * @return {Array}         [segmentIndex,nodeIndex]
###
µ.getSegmentIndex = (segment)->
    segmentI = 0
    for sibling, i in segment.parentNode.childNodes
        if sibling.classList.contains('CNE_task_btn')
            segmentI += -1
        if sibling == segment
            segmentI += i
            break
    return [segmentI,i] # [segmentIndex,nodeIndex]

µ.getNodeIndex = (node)->
    for sibling, i in node.parentNode.childNodes
        if sibling == node
            index = i
            break
    return index

selection = µ
exports.selection = µ
