
selection = {}

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
selection.cleanSelection = (startLine, endLine, range) ->
    if startLine is null
        startLine = endLine
        endLine   = endLine.lineNext
        selection.putStartOnStart range, startLine.line$[0].firstElementChild
        endLine.line$.prepend '<span></span>'
        selection.putEndOnStart range, endLine.line$[0].firstElementChild
    else
        startNode = startLine.line$[0].lastElementChild.previousElementSibling
        endNode   = endLine.line$[0].lastElementChild.previousElementSibling
        range.setStartAfter startNode, 0
        range.setEndAfter endNode, 0

selection.selectAll = (editor) ->
    range = document.createRange()
    range.setStartBefore(editor.linesDiv.firstChild)
    range.setEndAfter(editor.linesDiv.lastChild)
    selection.normalize(range)
    sel = editor.getEditorSelection()
    sel.removeAllRanges()
    sel.addRange(range)


###*
 * Called only once from the editor - TODO : role to be verified 
###
selection.cloneEndFragment = (range, endLine) ->
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
selection.normalize = (range) ->
    isCollapsed = range.collapsed
    newStartBP = selection.normalizeBP(range.startContainer, range.startOffset)
    range.setStart(newStartBP.cont,newStartBP.offset)
    if isCollapsed
        range.collapse(true)
    else
        newEndBP = selection.normalizeBP(range.endContainer, range.endOffset)
        range.setEnd(newEndBP.cont,newEndBP.offset)
    return range


###*
 * returns a break point in the most pertinent text node given a random bp.
 * @param  {element} cont   the container of the break point
 * @param  {number} offset offset of the break point
 * @return {object} the suggested break point : {cont:newCont,offset:newOffset}
###
selection.normalizeBP = (cont, offset) ->

    if cont.nodeName == '#text'
        # nothing to do
        res = {cont:cont,offset:offset}

    else if cont.nodeName == 'SPAN'
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
        # if offset in middle, put bp at the end of previous element
        # if offset before or after </br> put bp at the end of element
        # before </br>
        if offset == 0
            res = selection.normalizeBP(cont.firstChild,0)
        else if offset < cont.children.length-1
            newCont   = cont.children[offset-1]
            newOffset = newCont.childNodes.length
            res       = selection.normalizeBP(newCont, newOffset)
        else
            newCont   = cont.children[cont.children.length-2]
            newOffset = newCont.childNodes.length
            res       = selection.normalizeBP(newCont, newOffset)

    else if cont.nodeName ==  'DIV' and cont.id == "editor-lines"
        # if offset==0 put bp at begin of first node
        if offset == 0
            newCont   = cont.firstChild
            newOffset = 0
            res       = selection.normalizeBP(newCont, newOffset)
        # if bp is at end of container, put bp at end of last node
        else if offset == cont.childNodes.length
            newCont   = cont.lastChild
            newOffset = newCont.childNodes.length
            res       = selection.normalizeBP(newCont, newOffset)
        # if bp is in the middle of container, put bp at end of the node 
        # before current bp
        else
            newCont   = cont.children[offset-1]
            newOffset = newCont.childNodes.length
            res       = selection.normalizeBP(newCont, newOffset)

    if !res
        res = {cont:newCont,offset:newOffset}

    return res







### old normalize :

selection.normalize = (range) =>
    startDiv = selection.getStartDiv range
    endDiv   = selection.getEndDiv range, startDiv

    isEmptyLine = startDiv == endDiv and startDiv.innerHTML == '<span></span><br>'

    startContainer = range.startContainer

    if startContainer.nodeName == "BODY"
        selection.handleBodyStart range, startContainer, isEmptyLine

    else if startContainer.nodeName == "DIV"
        selection.handleDivStart range, startContainer

    else if startContainer.nodeName in ["SPAN","IMG","A"]
        selection.handleTextEltStart range, startContainer

    # if startC is a textNode ; do nothing

    endContainer = range.endContainer

    if endContainer.nodeName == "BODY"
        selection.handleBodyEnd range, endContainer

    if endContainer.nodeName == "DIV"
        selection.handleDivEnd range, endContainer

    else if endContainer.nodeName in ["SPAN","IMG","A"]
        selection.handleTextEltEnd range, endContainer

    # if endC is a textNode ;   do nothing

    return range


# Put selection start at the beginning of the first line of given editor body
selection.handleBodyStart = (range, startContainer) ->
    elt = selection.getFirstLineFromBody startContainer
    selection.putStartOnStart range, elt

# Put selection start at the end of the last line of given editor body
selection.handleBodyEnd = (range, endContainer) ->
    elt = selection.getLastLineFromBody endContainer
    selection.putEndAtEndOfLine range, elt

# Put selection start at the beginning of a workable element in given div 
# empty line are filled with a en empty span
# if caret is between two children <div>|<></>|<></> <br> </div>
#      pust start on start offset
# if caret is around <br> <div> <></> <></>|<br>|</div>
selection.handleDivStart = (range, startContainer, isEmptyLine) ->
    if isEmptyLine
        selection.putStartOnFirstChild range, startContainer
    else if range.startOffset < startContainer.childNodes.length - 1
        selection.putStartOnOffset range, startContainer, range.startOffset
    else
        selection.putStartAtEndOfLine range, startContainer
 
# if caret is between two children <div>|<></>|<></> <br> </div>
# if caret is around <br>          <div> <></> <></>|<br>|</div>
selection.handleDivEnd = (range, endContainer) ->
    if range.endOffset < endContainer.childNodes.length - 1
        selection.putEndOnOffset range, endContainer, range.endOffset
    else
        selection.putEndAtEndOfLine range, endContainer

# Put selection start at the beginning of a workable element around given elt. 
selection.handleTextEltStart = (range, startContainer) ->
    # 2.0 if startC is empty
    if startContainer.firstChild == null || startContainer.textContent.length == 0
        selection.putStartOnEnd range, startContainer
    # 2.1 if caret is between two textNode children
    else if range.startOffset < startContainer.childNodes.length
        selection.putStartOnNextChild range, startContainer
    # 2.2 if caret is after last textNode
    else
        selection.putStartOnLastChildEnd range, startContainer

# 2.0 if endC is empty
# 2.1 if caret is between two textNode children
# 2.2 if caret is after last textNode
selection.handleTextEltEnd = (range, endContainer) ->
    if endContainer.firstChild == null || endContainer.textContent.length == 0
        selection.putEndOnEnd range, endContainer
    if range.endOffset < endContainer.childNodes.length
        selection.putEndOnNextChild range, endContainer
    else
        selection.putEndOnLastChildEnd range, endContainer


# Get first line from given editor body.
selection.getFirstLineFromBody = (body) ->
    body.children[1].firstChild

# Get first line from given editor body.
selection.getLastLineFromBody = (body) ->
    body.children[1].lastChild

# Put start caret at beginning of first child of given container
selection.putStartOnFirstChild = (range, container) ->
    elt = container.firstChild
    selection.putStartOnStart range, elt

# Put start caret at offset position  of first child of given container
selection.putStartOnOffset = (range, container, offset) ->
    elt = container.childNodes[offset]
    selection.putStartOnStart range, elt

selection.putEndOnOffset = (range, container, offset) ->
    elt = container.childNodes[offset]
    selection.putEndOnStart range, elt

# Put selection start at the en of given line. 
# not sure about the result,
# TODO: code should be tested/verified
selection.putStartOnNextChild  = (range, container) ->
    elt = container.childNodes[range.startOffset]
    range.setStart elt, 0

selection.putEndOnNextChild  = (range, container) ->
    elt = container.childNodes[range.endOffset]
    range.setEnd elt, 0

#TODO:  Check if it should handle the br at the end of the line.
selection.putStartOnLastChildEnd = (range, container) ->
    elt = container.lastChild
    offset = elt.data.length
    range.setStart elt, offset

selection.putEndOnLastChildEnd = (range, container) ->
    elt = container.lastChild
    offset = elt.data.length
    range.setEnd elt, offset

# place caret at the end of the last child (before br)
# TODO: compare with putStartOnLastChildEnd 
selection.putStartAtEndOfLine = (range, container) ->
    elt = container.lastChild.previousElementSibling
    if elt?
        selection.putStartOnEnd range, elt
    else if container.lastChild?
        selection.putStartOnEnd container.lastChild
    else
        console.log "Normalize: no where to put selection start."
         
# TOOD: replace by putStartOnLastChildEnd  ?
selection.putEndAtEndOfLine = (range, container) ->
    elt = container.lastChild.previousElementSibling
    if elt?
        selection.putEndOnEnd range, elt
    else if container.lastChild?
        selection.putEndOnEnd container.lastChild
    else
        console.log "Normalize: no where to put selection start."

selection.putStartOnEnd = (range, elt) ->
    if elt?.lastChild?
        offset = elt.lastChild.textContent.length
        if offset == 0
            elt.lastChild.data = " "
            offset = 1
        range.setStart(elt.lastChild, offset)
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart(blank, 0)


selection.putEndOnEnd = (range, elt) ->
    if elt?
        range.setEnd elt.nextSibling, 0
    range


###


# Get line that contains given element.
# Prerequisite : elt must be in a div of a line.
selection._getLineDiv = (elt)->
    parent = elt
    while !(parent.nodeName == 'DIV'              \
            and parent.id?                        \
            and parent.id.substr(0,5) == 'CNID_') \
          or parent.parentNode == null
        parent = parent.parentNode
    return parent


###*
 * return the div corresponding to an element inside a line and tells wheter
 * the breabk point is at the end or at the beginning of the line
 * @param  {element} cont   the container of the break point
 * @param  {number} offset offset of the break point
 * @return {object}        {div[element], isStart[bool], isEnd[bool]}
###
selection.getLineDivIsStartIsEnd = (cont, offset)->
    
    parent = cont
    isStart = true
    isEnd = true

    # 1- walk trew each parent of the container until reaching the div 
    # on each parent check if breakpoint is still at the end or start
    while !(parent.nodeName == 'DIV'              \
            and parent.id?                        \
            and parent.id.substr(0,5) == 'CNID_') \
          and parent.parentNode != null

        # 1.1 check isStart isEnd
        isStart = isStart && (offset==0)
        if parent.length?
            isEnd = isEnd && (offset==parent.length)
        else
            isEnd = isEnd && (offset==parent.childNodes.length-1)
        # 1.2 prepare next loop :
        # 1.2.1 find offset of the current element among its siblings
        if parent.previousSibling == null
            offset = 0
        else if parent.nextSibling == null
            offset = parent.parentNode.childNodes.length - 1
        else if parent.nextSibling.nextSibling == null
            offset = parent.parentNode.childNodes.length - 2
        else
            # we are not at the beginning nor the end, we can set 1
            # to the parent offset because it is not important to know the
            # exact offset in this case
            offset = 1
        # 1.2.2 go up to the parent level
        parent = parent.parentNode

    # 2 check isStart isEnd for the div
    nodesNum = parent.childNodes.length
    isStart = isStart && (offset==0)
    if parent.textContent == '' # case : <div><span>|</br></div>
        isStart = true
    isEnd = isEnd && (offset==nodesNum-1 or offset==nodesNum-2)

    return div:parent, isStart:isStart, isEnd:isEnd


# BJA : usage qu'interne, à voir.
selection.putStartOnStart = (range, elt) ->
    if elt?.firstChild?
        offset = elt.firstChild.textContent.length
        if offset == 0 then elt.firstChild.data = " "
        range.setStart elt.firstChild, 0
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart blank, 0
 

# BJA : usage qu'interne, à voir.
selection.putEndOnStart = (range, elt) ->
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
selection.getLineDiv = (cont,offset) ->
    if cont.nodeName == 'DIV' 
        if cont.id == 'editor-lines'
            startDiv = cont.children[offset]
        else
            startDiv = selection._getLineDiv(cont)
    else
        startDiv = selection._getLineDiv(cont)
    return startDiv


exports.selection = selection
