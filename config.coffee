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
                'javascripts/app.js'     : /^app/
                'javascripts/vendor.js'  : /^vendor/
                'javascripts/tests.js'   : /^test/
            order:
                before: [
                    'vendor/scripts/jquery-1.8.2.js'
                    'vendor/scripts/lodash-v0.8.2.js'
                    'vendor/scripts/backbone-0.9.2.js'
                ]

        stylesheets:
            joinTo:
                'stylesheets/app.css': /(^vendor\/styles)|(^app\/views\/styles)|(^app\/views\/CNeditor\/)/
                'stylesheets/CNeditor.css': /(^app\/views\/CNeditor\/)/
            order:
                before: ['vendor/styles/normalize.css']
                after: ['vendor/styles/helpers.css']

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'

        #modules:
            #definition: (path, data) ->
                #data += """
                #selection = exports.selection;
                #"""
