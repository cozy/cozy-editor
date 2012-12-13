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
                './CNeditor.js': /^app\/views\/CNeditor\/.*\.coffee$/
                'javascripts/tests.js': /^test/

            order:
                before: [
                    'app/views/CNeditor/md2cozy.coffee'
                    'app/views/CNeditor/selection.coffee'
                ]

        stylesheets:
            joinTo:
                './CNeditor.css': /^app\/views\/CNeditor/

    modules:
        wrapper: false
        definition:  (path, data) ->
            if path == "public/CNeditor.js"
                """
                exports = {};
                """

                #data = data.replace(/exports\.CNeditor.*/g, "CNeditor")
                #data = data.replace(/exports\.md2cozy.*/g, "md2cozy")
                #data = data.replace(/exports\.cozy2md.*/g, "cozy2md")
                #data = data.replace("md2cozy = require('./md2cozy').md2cozy;", "")
                #data = data.replace("selection = require('./selection').selection;", "")
                #data = data.replace(/^CNeditor$/, "")
                #data = data.replace("})();", "")

                #data = data.replace("exports.CNeditor = (function() {", "")
                #data = data.replace("return CNeditor;", "")
                #data = data.replace("exports.md2cozy = md2cozy;", "")
                #data = data.replace("exports.selection = selection;", "")
                #data = data.replace("md2cozy = require('./md2cozy').md2cozy;")
                #data = data.replace("selection = require('./selection').selection;")

                #data = data.replace(new RegExp("exports.", "g"), "")
                #data = data.replace(/^require.*/, "")

    # minify: true
    # optimize: true
    # none of those syntax work, there is a pb in the documentation : 
    # http://brunch.readthedocs.org/en/latest/config.html#optimize
