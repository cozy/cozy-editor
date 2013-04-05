exports.config =
    # See docs at http://brunch.readthedocs.org/en/latest/config.html.
    coffeelint:
        pattern: /^app\/.*\.coffee$/
        options:
            indentation:
                value: 4
                level: "ignore"
            max_line_length:
                value: 80
                level: "ignore"
            no_trailing_whitespace:
                level: "ignore"
            no_trailing_semicolons:
                level: "ignore"
            no_backticks:
                level: "ignore"

    files:
        javascripts:
            joinTo:

                # comment & uncomment (here & at the module wrapper)
                # depending your needs :

                # for deployement in "public/CNeditor.js"
                # './CNeditor.js': /^app\/views\/CNeditor\/.*\.coffee$/

                # for deployement directly in cozy-notes
                '../../cozy-notes/client/vendor/scripts/CNeditor.js': /^app\/CNeditor\/.*\.coffee$/


                'javascripts/tests.js': /^test/

            order:
                before: [
                    'app/CNeditor/selection.coffee'
                    'app/CNeditor/md2cozy.coffee'
                    'app/CNeditor/task.coffee'
                ]

        stylesheets:
            joinTo:
                './CNeditor.css': /^app\/CNeditor/

    modules:
#         wrapper: (path, data) ->
#             path = path.slice(1,-1)
#             dir = path.split('/')
#             console.log 'entry : ' , path

#             # views/CNeditor/CNeditor
#             # console.log dir[0], dir[1], dir[2], dir[0]+'' == 'views', dir[1] == 'CNeditor'
#             if dir[0] == 'views' && dir[1] == 'CNeditor'
                
#                 if dir[2] == 'CNeditor'
#                     path = 'CNeditor'
#                 else
#                     dir.shift()
#                     path = dir.join('/')
#             console.log 'end   : ', path
#             return """
# window.require.define({"#{path}": function(exports, require, module) {
#   #{data}
# }});\n\n
#             """
        wrapper: 'commonjs'
        # wrapper: false
        # definition:  (path, data) ->
        #     # for deployement in "public/CNeditor.js"
        #     # if path == "public/CNeditor.js"
        #     # for deployement in "public/CNeditor.js"
        #     if path == "../cozy-notes/client/vendor/scripts/CNeditor.js"
                
        #         """
        #         exports = {};
        #         """

    # minify: true
    # optimize: true
    # none of those syntax work, there is a pb in the documentation : 
    # http://brunch.readthedocs.org/en/latest/config.html#optimize
