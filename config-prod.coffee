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
                '../../cozy-notes/client/vendor/scripts/CNeditor.js': /^app\/views\/CNeditor\/.*\.coffee$/


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
            # for deployement in "public/CNeditor.js"
            # if path == "public/CNeditor.js"
            # for deployement in "public/CNeditor.js"
            if path == "../cozy-notes/client/vendor/scripts/CNeditor.js"
                
                """
                exports = {};
                """

    # minify: true
    # optimize: true
    # none of those syntax work, there is a pb in the documentation : 
    # http://brunch.readthedocs.org/en/latest/config.html#optimize
