 
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

if !String::trim
    String::trim = -> this.replace(/^\s+|\s+$/g, '')

### ------------------------------------------------------------------------
#  _cozy2md
# Turns line elements form editor into a string in markdown format
###
md2cozy.cozy2md = (linesDiv) ->

    md2cozy.currentDepth = 0

    lines = []
    prevLineMetaData = null

    for line in linesDiv.children()
        if line.id == 'CNE_urlPopover'
            continue
        line = $ line
        lineMetaData = md2cozy.getLineMetadata(line.attr 'class')
        markCode = md2cozy.buildMarkdownPrefix lineMetaData, prevLineMetaData
        prevLineMetaData = lineMetaData

        for segment in line.children()
            if segment.nodeType == 1
                markCode += md2cozy.convertInlineEltToMarkdown($ segment)
            else
                markCode += $(segment).text()

        lines.push markCode
    
    lines.join ''


# Get metadata from line class name
md2cozy.getLineMetadata = (name) ->
    if name?
        data = name.split "-"
        type = data[0] # type of class (Tu,Lu,Th,Lh,To,Lo)
        depth = parseInt(data[1], 10) # depth (1,2,3...)

        type: type, depth: depth
    else
        type: null, depth: null

# Build markdown prefix corresponding to line type.
# Th = title => ###
# Lh = simple line => nothing
# Tu = bullet point => blank spaces + *
# Lu = simple line => blank spaces
md2cozy.buildMarkdownPrefix = (metadata, prevMetadata) ->

    blanks= ""
    switch metadata.type
        when 'Th'
            dieses = ''
            dieses += '#' for i in [1..metadata.depth]
            md2cozy.currentDepth = metadata.depth
            prefix = "#{dieses} "
            prefix = "\n\n" + prefix if prevMetadata?
            prefix
        when 'Lh'
            "\n\n"
        when 'Tu'
            nbBlanks = (metadata.depth - md2cozy.currentDepth - 1)
            if nbBlanks > 0
                blanks += '    ' for i in [0..nbBlanks - 1]
            prefix = "#{blanks}* "
            if prevMetadata?.type is "Tu" or prevMetadata?.type is "Lu"
                prefix = "\n" + prefix
            else if prevMetadata?
                prefix = "\n\n" + prefix
            prefix
        when 'Lu'
            nbBlanks = (metadata.depth - md2cozy.currentDepth - 1)
            if nbBlanks > 0
                blanks += '    ' for i in [0..nbBlanks - 1]
            "\n\n#{blanks} "
        else
            ''

# Convert inline element (a, img, span) to Markdown.
md2cozy.convertInlineEltToMarkdown = (obj) ->
    switch obj[0].nodeName
        when 'A'
            title = if obj.attr('title')? then obj.attr('title') else ""
            href  = if obj.attr('href')? then obj.attr('href') else ""
            return '[' + obj.html() + '](' + href + ' "' + title + '")'
        when 'IMG'
            title = if obj.attr('title')? then obj.attr('title') else ""
            alt   = if obj.attr('alt')? then obj.attr('alt') else ""
            src   = if obj.attr('src')? then obj.attr('src') else ""
            return '![' + alt + '](' + src + ' "' + title + '")'
        when 'SPAN'
            classList = obj[0].classList
            if classList.contains('CNE_strong')
                return '**' + obj.text() + '**'
            # underline is not in the standard md syntax...
            else if classList.contains('CNE_underline')
                return obj.text()
            else
                return obj.text()
        else
            return ''

### ------------------------------------------------------------------------
# Read a string of html code given by showdown and turns it into a string
# of editor html code
###
md2cozy.md2cozy = (text) ->
    conv = new Showdown.converter()
    htmlCode = $(conv.makeHtml text)
    
    cozyCode = ''
    md2cozy.currentId = 0
    md2cozy.editorDepth = 0
    
    # Reads recursively through the lists
    htmlCode.each () ->
        cozyCode += md2cozy.parseLine $ @

    if cozyCode.length == 0
        cozyCode = md2cozy.buildEditorLine("Tu", 1, null)

    return cozyCode

# Read sections sequentially
md2cozy.parseLine = (obj) ->
    tag = obj[0].tagName
    if tag? and tag[0] is "H" # that's a title (h1...h6)
        md2cozy.editorDepth = parseInt tag[1], 10
        return md2cozy.buildEditorLine "Th", md2cozy.editorDepth, obj
    else if tag? and tag is "P"
        return md2cozy.buildEditorLine "Lh", md2cozy.editorDepth, obj
    else
        return md2cozy.parseList obj

# build an editor line from given data: its type, its depth and normalize
# its content to fit well with cozy stylesheet.
md2cozy.buildEditorLine = (type, depth, obj) ->
    md2cozy.currentId++
    code = ''
    if obj?
        obj.contents().each () ->
            name = @nodeName
            if name == "#text"
                code += "<span>#{$(@).text()}</span>"
            else if @tagName?
                $(@).wrap('<div></div>')
                code += "#{$(@).parent().html()}"
                $(@).unwrap()
                
    code = "<span></span>" if code is ""
    return "<div id=CNID_#{md2cozy.currentId} class=#{type}-#{depth}>" + code +
        "<br></div>"

md2cozy.parseList = (obj) ->
    tag = obj[0].tagName
    cozyCode = ""

    if tag? and tag is "UL"

        md2cozy.editorDepth++
        obj.children().each () ->
            cozyCode += md2cozy.parseList $(@)
        md2cozy.editorDepth--

    else if tag? and tag is "LI" and obj.contents().get(0)?

        for child, i in obj[0].childNodes
            child = $ child
            type = "Lu"
            type = "Tu" if i is 0
            nodeName = child[0].nodeName
        
            if nodeName is "#text" and child.text().trim() != ""
                child = child.clone().wrap('<p></p>').parent()
                cozyCode +=
                    md2cozy.buildEditorLine type, md2cozy.editorDepth, child
            else if nodeName is "P"
                cozyCode +=
                    md2cozy.buildEditorLine type, md2cozy.editorDepth, child
            else
                cozyCode += md2cozy.parseList child

    else if tag? and tag is "P"

        cozyCode += md2cozy.buildEditorLine "Lu", md2cozy.editorDepth, obj

    return cozyCode

exports.md2cozy = md2cozy
