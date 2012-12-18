
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

###*
 * Called only once from the editor - TODO : role to be verified 
###
selection.cloneEndFragment = (range, endLine) ->
    range4fragment = rangy.createRangyRange()
    range4fragment.setStart range.endContainer, range.endOffset
    range4fragment.setEndAfter endLine.line$[0].lastChild
    range4fragment.cloneContents()

### ------------------------------------------------------------------------
#  _normalize(range)
# 
#  Modify 'range' containers and offsets so it represent a clean selection
#  that it starts inside a textNode and ends inside a textNode.
#
#  Set the flag isEmptyLine to true if an empty line is being normalized
#  so further suppr ~ backspace work properly.
# 
###
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
selection.handleTextEltEnd = (range, startContainer) ->
    if endContainer.firstChild == null || endContainer.textContent.length == 0
        selection.putEndOnEnd range, endContainer
    if range.endOffset < endContainer.childNodes.length
        selection.putEndOnNextChild range, endContainer
    else
        selection.putEndOnLastChildEnd range, startContainer


# Get line that contains given element.
selection.getLineDiv = (elt)->
    parent = elt
    while parent.nodeName != 'DIV' \
          and ((parent.id? and parent.id.substr(0,5) != 'CNID_') \
                or not parent.id?) \
          and parent.parentNode != null
        parent = parent.parentNode
    return parent

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
    elt = endContainer.childNodes[offset]
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

selection.putStartOnStart = (range, elt) ->
    if elt?.firstChild?
        offset = elt.firstChild.textContent.length
        if offset == 0 then elt.firstChild.data = " "
        range.setStart elt.firstChild, 0
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart blank, 0

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
 
selection.putEndOnStart = (range, elt) ->
    if elt?.firstChild?
        offset = elt.firstChild.textContent.length
        elt.firstChild.data = " " if offset == 0
        range.setEnd(elt.firstChild, 0)
    else if elt?
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setEnd(blank, 0)

selection.putEndOnEnd = (range, elt) ->
    if elt?
        range.setEnd elt.nextSibling, 0
    #if elt?.lastChild?
        #range.setEnd elt.nextSibling, 0
        ##offset = elt.lastChild.textContent.length
        ##elt.lastChild.data += " "

        ## offset = offset - 1 if offset > 0
        ##range.setEnd elt.lastChild, offset
        ## elt.lastChild.data = elt.lastChild.data.substring(0, elt.lastChild.data.length - 1)
    #else if elt?
        #blank = document.createTextNode " "
        #elt.appendChild blank
        #range.setEnd(blank, 1)
    range

# Determine selection start div even if selection start in the body element or
# inside a div child element.
selection.getStartDiv = (range) ->
    if range.startContainer.nodeName == 'BODY'
        startDiv = range.startContainer.children[range.startOffset]
    else
        startDiv = range.startContainer

    if startDiv.nodeName != "DIV"
        startDiv = selection.getLineDiv startDiv
    startDiv

# Determine selection end div even if selection ends in the body element or
# inside a div child element.
selection.getEndDiv = (range, startDiv) ->
    if range.endContainer.nodeName == "BODY"
        endDiv = range.endContainer.children[range.endOffset - 1]
    else
        endDiv = range.endContainer

    if endDiv?.nodeName != "DIV"
        endDiv = selection.getLineDiv endDiv
    else
        endDiv = startDiv
    endDiv

exports.selection = selection
