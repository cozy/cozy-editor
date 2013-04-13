
###* -----------------------------------------------------------------------
 * line$        : 
 * lineID       : 
 * lineType     : 
 * lineDepthAbs : 
 * lineDepthRel : 
 * lineNext     : 
 * linePrev     : 
###
class Line
    ###
     * If no arguments, returns an empty object (only methods), otherwise
     * constructs a full line. The dom element of the line is inserted according
     * to the previous or next line given in the arguments.
     * @param  {Array}  Array of parameters :
     *   [ 
            editor        , # 
            type          , # 
            depthAbs      , # 
            depthRelative , # 
            prevLine      , # The prev line, null if nextLine is given
            nextLine      , # The next line, null if prevLine is given
            fragment        # [optional] a fragment to insert in the line, will
                              add a br at the end if none in the fragment.
          ]
    ###
    constructor : ( ) ->
        if arguments.length == 0
            return
        else
            [ 
              editor        , # 
              type          , # 
              depthAbs      , # 
              depthRelative , # 
              prevLine      , # The prev line, null if nextLine is given
              nextLine      , # The next line, null if prevLine is given
              fragment        # [optional] a fragment to insert in the line
            ] = arguments
        # Increment the counter for lines id
        editor._highestId += 1
        # Initialise with an empty line or the fragment given in arguments
        lineID = 'CNID_' + editor._highestId
        newLineEl = document.createElement('div')
        
        newLineEl.setAttribute('class', type + '-' + depthAbs)
        if fragment?
            newLineEl.appendChild(fragment)
            if newLineEl.lastChild.nodeName != 'BR'
                newLineEl.appendChild(document.createElement('br'))
        else
            node = document.createElement('span')
            node.appendChild(document.createTextNode(''))
            newLineEl.appendChild(node)
            newLineEl.appendChild(document.createElement('br'))
        @line$ = $(newLineEl)
        
        if prevLine?
            @.linePrev = prevLine
            linesDiv = prevLine.line$[0].parentNode
            if prevLine.lineNext?
                nextL = prevLine.lineNext
                linesDiv.insertBefore(newLineEl,nextL.line$[0])
                @.lineNext     = nextL
                nextL.linePrev = @
            else
                linesDiv.appendChild(newLineEl)
                @.lineNext = null
            prevLine.lineNext = @
            
        else if nextLine?
            linesDiv = nextLine.line$[0].parentNode
            @.lineNext = nextLine
            linesDiv.insertBefore(newLineEl,nextLine.line$[0])
            if nextLine.linePrev? 
                @.linePrev = nextLine.linePrev
                nextLine.linePrev.lineNext = @
            else
                @.linePrev = null
            nextLine.linePrev = @
        
        newLineEl.id   = lineID
        @.lineID       = lineID
        @.lineType     = type
        @.lineDepthAbs = depthAbs
        @.lineDepthRel = depthRelative
        editor._lines[lineID] = @
        

    setType : (type) ->
        @lineType = type
        @line$.prop('class',"#{type}-#{@lineDepthAbs}")

    setDepthAbs : (absDepth) ->
        @lineDepthAbs = absDepth
        @line$.prop('class',"#{@lineType}-#{absDepth}")

    setTypeDepth : (type, absDepth) ->
        @lineType = type
        @lineDepthAbs = absDepth
        @line$.prop('class',"#{type}-#{absDepth}")

Line.clone = (line) ->
    clone = new Line()
    clone.line$        = line.line$.clone()
    clone.lineID       = line.lineID
    clone.lineType     = line.lineType
    clone.lineDepthAbs = line.lineDepthAbs
    clone.lineDepthRel = line.lineDepthRel
    clone.linePrev     = line.linePrev
    clone.lineNext     = line.lineNext
    return clone

module.exports = Line