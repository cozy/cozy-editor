any = (a, b) ->
  a or b

read_settings_from_cookie = ->
  $("#tabsize").val any($.cookie("tabsize"), "4")
  $("#brace-style").val any($.cookie("brace-style"), "collapse")
  $("#detect-packers").attr "checked", $.cookie("detect-packers") isnt "off"
  $("#preserve-newlines").attr "checked", $.cookie("preserve-newlines") isnt "off"
  $("#keep-array-indentation").attr "checked", $.cookie("keep-array-indentation") is "on"
  $("#indent-scripts").val any($.cookie("indent-scripts"), "normal")
  $("#space-before-conditional").attr "checked", $.cookie("space-before-conditional") isnt "off"

store_settings_to_cookie = ->
  opts = expires: 360
  $.cookie "tabsize", $("#tabsize").val(), opts
  $.cookie "brace-style", $("#brace-style").val(), opts
  $.cookie "detect-packers", (if $("#detect-packers").attr("checked") then "on" else "off"), opts
  $.cookie "preserve-newlines", (if $("#preserve-newlines").attr("checked") then "on" else "off"), opts
  $.cookie "keep-array-indentation", (if $("#keep-array-indentation").attr("checked") then "on" else "off"), opts
  $.cookie "space-before-conditional", (if $("#space-before-conditional").attr("checked") then "on" else "off"), opts
  $.cookie "indent-scripts", $("#indent-scripts").val(), opts

unpacker_filter = (source) ->
  trailing_comments = ""
  comment = ""
  found = false
  loop
    found = false
    if /^\s*\/\*/.test(source)
      found = true
      comment = source.substr(0, source.indexOf("*/") + 2)
      source = source.substr(comment.length).replace(/^\s+/, "")
      trailing_comments += comment + "\n"
    else if /^\s*\/\//.test(source)
      found = true
      comment = source.match(/^\s*\/\/.*/)[0]
      source = source.substr(comment.length).replace(/^\s+/, "")
      trailing_comments += comment + "\n"
    break unless found
  # source = unpacker_filter(P_A_C_K_E_R.unpack(source))  if P_A_C_K_E_R.detect(source)
  # source = unpacker_filter(Urlencoded.unpack(source))  if Urlencoded.detect(source)
  # source = unpacker_filter(JavascriptObfuscator.unpack(source))  if JavascriptObfuscator.detect(source)
  # source = unpacker_filter(MyObfuscate.unpack(source))  if MyObfuscate.detect(source)
  # trailing_comments + source

exports.beautify = (source) ->
  return  if the.beautify_in_progress
  the.beautify_in_progress = true
  comment_mark = "<-" + "-"
  opts =
    indent_size: 2
    indent_char: " "
    preserve_newlines: true
    brace_style: "collapse"
    keep_array_indentation: false
    space_after_anon_function: true
    space_before_conditional: true
    indent_scripts: "normal"

  the.beautify_in_progress = false
  return style_html(source, opts)

the = beautify_in_progress: false