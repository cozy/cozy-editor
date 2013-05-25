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
                'javascripts/vendor.js'  : /^(vendor)|(CNeditor)/
                'javascripts/app.js'     : /^app/
                'javascripts/tests.js'   : /^test/
            order:
                before: [
                    'vendor/scripts/CNeditor-dependencies/jquery-1.8.2.js'
                    'vendor/scripts/CNeditor-dependencies/bootstrap-datepicker.js'
                    'vendor/scripts/underscore-1.4.4.js'
                    'vendor/scripts/backbone-1.0.0.js'
                ]

        stylesheets:
            joinTo:
                'stylesheets/app.css': /(^app\/CNeditor)|(^vendor\/styles)|(^app\/views\/styles)/
                'stylesheets/CNeditor.css': /(^app\/CNeditor\/)/
            order:
                before: [
                    'vendor/styles/normalize.css'
                    'app/CNeditor/datepicker.css'
                    ]
                after: ['vendor/styles/helpers.css']

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'

        #modules:
            #definition: (path, data) ->
                #data += """
                #selection = exports.selection;
                #"""
