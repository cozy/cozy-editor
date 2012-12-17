 
### ------------------------------------------------------------------------
#  MARKUP LANGUAGE CONVERTERS
# _cozy2md (Read a string of editor html code format and turns it into a
#           string in markdown format)
# _md2cozy (Read a string of html code given by showdown and turns it into
#           a string of editor html code)
###

#  BUG --> : an odd bug occurs around the 19-th line in the example :
#           ./templates/content-shortlines-marker
#           (there are some empty lines around)
 
md2cozy = {}

### ------------------------------------------------------------------------
#  _cozy2md
# Read a string of editor html code format and turns it into a string in
#  markdown format
###
md2cozy.cozy2md = (text) ->
    
    # Writes the string into a jQuery object
    htmlCode = $(document.createElement 'div').html text
    htmlCode = htmlCode.find('#editor-lines') if htmlCode.id != 'editor-lines'
    
    # The future converted line
    markCode = ''

    # current depth
    currDepth = 0
    
    # converts a fragment of a line
    converter =
        'A': (obj) ->
            title = if obj.attr('title')? then obj.attr('title') else ""
            href  = if obj.attr('href')? then obj.attr('href') else ""
            return '[' + obj.html() + '](' + href + ' "' + title + '")'
                
        'IMG': (obj) ->
            title = if obj.attr('title')? then obj.attr('title') else ""
            alt   = if obj.attr('alt')? then obj.attr('alt') else ""
            src   = if obj.attr('src')? then obj.attr('src') else ""
            return '![' + alt + '](' + src + ' "' + title + '")'
            
        'SPAN': (obj) ->
            return obj.text()
    
    # markup symbols
    # Th = title
    # Tu = bullet point
    # Lh = simple line
    # Lu = simple line
    markup =
        'Th' : (blanks, depth) ->
            currDepth = depth
            dieses = ''
            i = 0
            while i < depth
                dieses += '#'
                i++
            "\n\n" + dieses + ' '
        'Lh' : (blanks, depth) ->
            "\n\n"
        'Tu' : (blanks, depth, changeDepth) ->
            "\n" + blanks + "+   "
        'Lu' : (blanks, depth) ->
            "\n\n" + blanks + "    "
        'To' : (blanks, depth) ->
            "\n\n" + blanks + "1.   "
        'Lo' : (blanks, depth) ->
            "\n\n" + blanks + "    "

    previousDepth = 0
    # adds structure depending of the line's class
    classType = (className) ->
        tab   = className.split "-"
        type  = tab[0]               # type of class (Tu,Lu,Th,Lh,To,Lo)
        depth = parseInt(tab[1], 10) # depth (1,2,3...)
        changeDepth = depth != previousDepth
        previousDepth = depth
        blanks = ''
        i = 1
        while i < depth - currDepth
            blanks += '    '
            i++
        return markup[type](blanks, depth, changeDepth)
    
    lines = []
    for child in htmlCode.children()
        markCode = ''
        lineCode = $ child
        
        # indent and structure the line
        lineClass = lineCode.attr 'class'
        markCode += classType(lineClass) if lineClass?

        # completes the text depending of the line's content
        l = lineCode.children().length
        j = 0
        space = ' '
        while j < l
            lineElt = lineCode.children().get j
            # be sure not to insert spaces after BR
            if (j + 2 == l) then space = ''
            if lineElt.nodeType == 1 && converter[lineElt.nodeName]?
                markCode += converter[lineElt.nodeName]($ lineElt) + space
            else
                markCode += $(lineElt).text() + space
            j++

        lines.push markCode
    
    lines.join ''


### ------------------------------------------------------------------------
# Read a string of html code given by showdown and turns it into a string
# of editor html code
###
md2cozy.md2cozy = (text) ->
    conv = new Showdown.converter()
    text = conv.makeHtml text
   
    # Writes the string into a jQuery object
    htmlCode = $(document.createElement 'ul').html text

    # final string
    cozyCode = ''
    
    # current line
    id = 0

    # Returns the corresponding fragment of cozy Code
    cozyTurn = (type, depth, p) ->
        # p is a (jquery) object that looks like this :
        # <p> some text <a>some link</a> again <img>some img</img> poof </p>
        # OR like this:  <li> some text <a>some link</a> ...
        # We are treating a line again, thus id must be increased
        id++
        code = ''
        if p?
            p.contents().each () ->
                name = @nodeName
                if name == "#text"
                    code += "<span>#{$(@).text()}</span>"
                else if @tagName?
                    $(@).wrap('<div></div>')
                    code += "#{$(@).parent().html()}"
                    $(@).unwrap()
        else
            code = "<span></span>"
        return "<div id=CNID_#{id} class=#{type}-#{depth}>" + code +
            "<br></div>"
            
    # current depth
    depth = 0
    
    # Read sections sequentially
    readHtml = (obj) ->
        tag = obj[0].tagName
        if tag[0] == "H"       # c'est un titre (h1...h6)
            depth = parseInt(tag[1],10)
            cozyCode += cozyTurn("Th", depth, obj)
        else if tag == "P"     # ligne de titre
            cozyCode += cozyTurn("Lh", depth, obj)
        else
            recRead(obj, "u")
            
    # Reads recursively through the lists
    recRead = (obj, status) ->
        tag = obj[0].tagName
        if tag == "UL"
            depth++
            obj.children().each () ->
                recRead($(@), "u")
            depth--
        else if tag == "OL"
            depth++
            obj.children().each () ->
                recRead($(@), "o")
            depth--
        else if tag == "LI" && obj.contents().get(0)?
            # cas du <li>Un seul titre sans lignes en-dessous</li>
            if obj.contents().get(0).nodeName == "#text"
                obj = obj.clone().wrap('<p></p>').parent()
            for i in [0..obj.children().length-1]
                child = $ obj.children().get i
                if i == 0
                    cozyCode += cozyTurn("T#{status}", depth, child)
                else
                    recRead(child, status)
        else if tag == "P"
            cozyCode += cozyTurn("L#{status}", depth, obj)

    htmlCode.children().each () ->
        readHtml $ @

    if cozyCode.length == 0
        cozyCode = cozyTurn("Tu", 1, null)

    return cozyCode

exports.md2cozy = md2cozy
