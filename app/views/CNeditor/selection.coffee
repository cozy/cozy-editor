
### ------------------------------------------------------------------------
# UTILITY FUNCTIONS
# used to set ranges and help normalize selection
# 
# parameters: elt  :  a dom object with only textNode children
#
# note: with google chrome, it seems that non visible elements
#       cannot be selected with rangy (that's where 'blank' comes in)
###
exports.putStartOnStart = (range, elt) ->
    if elt.firstChild?
        offset = elt.firstChild.textContent.length
        if offset == 0 then elt.firstChild.data = " "
        range.setStart elt.firstChild, 0
    else
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart blank, 0

exports.putStartOnEnd = (range, elt) ->
    if elt.lastChild?
        offset = elt.lastChild.textContent.length
        if offset == 0
            elt.lastChild.data = " "
            offset = 1
        range.setStart(elt.lastChild, offset)
    else
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setStart(blank, 0)
        
exports.putEndOnStart = (range, elt) ->
    if elt.firstChild?
        offset = elt.firstChild.textContent.length
        if offset == 0 then elt.firstChild.data = " "
        range.setEnd(elt.firstChild, 0)
    else
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setEnd(blank, 0)
        
exports.putEndOnEnd = (range, elt) ->
    if elt.lastChild?
        offset = elt.lastChild.textContent.length
        if offset == 0
            elt.lastChild.data = " "
            offset = 1
        range.setEnd(elt.lastChild, offset)
    else
        blank = document.createTextNode " "
        elt.appendChild blank
        range.setEnd(blank, 1)

# Determine selection start div even if selection start in the body element or
# inside a div child element.
exports.getStartDiv = (range) ->
    if range.startContainer.nodeName == 'BODY'
        startDiv = range.startContainer.children[range.startOffset]
    else
        startDiv = range.startContainer

    if startDiv.nodeName != "DIV"
        startDiv = $(startDiv).parents("div")[0]
    startDiv

# Determine selection end div even if selection ends in the body element or
# inside a div child element.
exports.getEndDiv = (range, startDiv) ->
    if range.endContainer.nodeName == "BODY"
        endDiv = range.endContainer.children[range.endOffset - 1]
    else
        endDiv   = range.endContainer

    if endDiv?.nodeName != "DIV"
        endDiv = $(endDiv).parents("div")[0]
    else
        endDiv = startDiv
    endDiv

exports.getLineDiv = (container)->
    parent = container
    while parent.nodeName != 'DIV' \
          and ((parent.id? and parent.id.substr(0,5) != 'CNID_') \
                or not parent.id?) \
          and parent.parentNode != null
        parent = parent.parentNode
    return parent


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
exports.normalize = (range) =>
    startDiv = exports.getStartDiv range
    endDiv = exports.getEndDiv range, startDiv

    isEmptyLine = startDiv == endDiv and startDiv.innerHTML == '<span></span><br>'

    startContainer = range.startContainer

    # 0. if start is the body
    if startContainer.nodeName == "BODY"
        elt = startContainer.children[range.startOffset]
        exports.putStartOnStart range, elt

    # 1. if startC is a div
    else if startContainer.nodeName == "DIV"
        # 1.1 if line is empty
        if isEmptyLine
            # empty line are filled with a en empty span
            elt = startContainer.childNodes[0]
            exports.putStartOnStart range, elt
        # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
        else if range.startOffset < startContainer.childNodes.length - 1
            # place caret at the beginning of the next child
            elt = startContainer.childNodes[range.startOffset]
            exports.putStartOnStart range, elt
        # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
        else
            # place caret at the end of the last child (before br)
            elt = startContainer.lastChild.previousElementSibling
            exports.putStartOnEnd range, elt
           
    # 2. if startC is a span, a, img
    else if startContainer.nodeName in ["SPAN","IMG","A"]
        # 2.0 if startC is empty
        if startContainer.firstChild == null || startContainer.textContent.length == 0
            exports.putStartOnEnd range, startContainer
        # 2.1 if caret is between two textNode children
        else if range.startOffset < startContainer.childNodes.length
            # place caret at the beginning of the next child
            targetChild = startContainer.childNodes[range.startOffset]
            range.setStart targetChild, 0
        # 2.2 if caret is after last textNode
        else
            # place caret at the end of the last child
            targetChild = startContainer.lastChild
            offset = targetChild.data.length
            range.setStart targetChild, offset
    # 3. if startC is a textNode ;   do nothing


    endContainer = range.endContainer
    # 0. if endC is the body
    if endContainer.nodeName == "BODY"
        elt = endContainer.children[range.endOffset-1].lastChild
        exports.putEndOnEnd range, elt.previousElementSibling
    # 1. if endC is a div
    if endContainer.nodeName == "DIV"
        # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
        if range.endOffset < endContainer.childNodes.length - 1
            # place caret at the beginning of the next child
            elt = endContainer.childNodes[range.endOffset]
            exports.putEndOnStart range, elt
        # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
        else
            # place caret at the end of the last child (before br)
            elt = endContainer.lastChild.previousElementSibling
            exports.putEndOnEnd range, elt
            
    # 2. if endC is a span, a, img
    else if endContainer.nodeName in ["SPAN","IMG","A"]
        # 2.0 if endC is empty
        if endContainer.firstChild == null || endContainer.textContent.length == 0
            exports.putEndOnEnd range, endContainer
        # 2.1 if caret is between two textNode children
        if range.endOffset < endContainer.childNodes.length
            # place caret at the beginning of the next child
            targetChild = startContainer.childNodes[range.endOffset]
            range.setEnd targetChild, 0
        # 2.2 if caret is after last textNode
        else
            # place caret at the end of the last child
            targetChild = endContainer.lastChild
            offset = targetChild.data.length
            range.setEnd targetChild, offset
    # 3. if endC is a textNode ;   do nothing

    return range
