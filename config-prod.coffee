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
                '../CNeditor.js': /^app\/views\/CNeditor\/.*\.coffee/
                'javascripts/tests.js': /^test/

        stylesheets:
            joinTo:
                '../CNeditor.css': /^app\/views\/CNeditor/

    modules:
        wrapper: false
        definition:  (path, data) ->
            if path == "public/bin/CNeditor.js"
                data = data.replace(/exports\.CNeditor/, "CNeditor")
                data = data.replace(/exports\.md2cozy/, "md2cozy")
                data = data.replace(/exports\.cozy2md/, "cozy2md")
                #data = data.replace(/.*require.*/, "")
                return data

    # minify: true
    # optimize: true
    # none of those syntax work, there is a pb in the documentation : 
    # http://brunch.readthedocs.org/en/latest/config.html#optimize
