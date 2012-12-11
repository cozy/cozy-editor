 
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
 
### ------------------------------------------------------------------------
#  _cozy2md
# Read a string of editor html code format and turns it into a string in
#  markdown format
###
exports.cozy2md = (text) ->
    
    # Writes the string into a jQuery object
    htmlCode = $(document.createElement 'div').html text
    
    # The future converted line
    markCode = ''

    # current depth
    currDepth = 0
    
    # converts a fragment of a line
    converter = {
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
        }

    
    # markup symbols
    markup = {
        'Th' : (blanks, depth) ->
            # a title is a section rupture
            currDepth = depth
            dieses = ''
            i = 0
            while i < depth
                dieses += '#'
                i++
            return "\n" + dieses + ' '
        'Lh' : (blanks, depth) ->
            return "\n"
        'Tu' : (blanks, depth) ->
            return "\n" + blanks + "+   "
        'Lu' : (blanks, depth) ->
            return "\n" + blanks + "    "
        'To' : (blanks, depth) ->
            return "\n" + blanks + "1.   "
        'Lo' : (blanks, depth) ->
            return "\n" + blanks + "    "
        }

    # adds structure depending of the line's class
    classType = (className) ->
        tab   = className.split "-"
        type  = tab[0]               # type of class (Tu,Lu,Th,Lh,To,Lo)
        depth = parseInt(tab[1], 10) # depth (1,2,3...)
        blanks = ''
        i = 1
        while i < depth - currDepth
            blanks += '    '
            i++
        return markup[type](blanks, depth)
    
    # iterate on direct children
    children = htmlCode.children()
    for i in [0..children.length-1]
        
        # fetch the i-th line of the text
        lineCode = $ children.get i
        
        # indent and structure the line
        if lineCode.attr('class')?
            # console.log classType lineCode.attr 'class'
            markCode += classType lineCode.attr 'class'

        # completes the text depending of the line's content
        l = lineCode.children().length
        j = 0
        space = ' '
        while j < l
            lineElt = lineCode.children().get j
            if (j+2==l) then space='' #be sure not to insert spaces after BR
            if lineElt.nodeType == 1 && converter[lineElt.nodeName]?
                markCode += converter[lineElt.nodeName]($ lineElt) + space
            else
                markCode += $(lineElt).text() + space
            j++
            
        # adds a new line at the end
        markCode += "\n"
    
    return markCode


### ------------------------------------------------------------------------
# Read a string of html code given by showdown and turns it into a string
# of editor html code
###
exports.md2cozy = (text) ->
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
