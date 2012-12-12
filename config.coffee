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
                # /app but not /app/views/CNeditor, it would be redundant
                'javascripts/app.js'     : /(^app)(?!(\/views\/CNeditor))/
                # the editor class is seperated in order to use the compiled
                # files in other projects
                'javascripts/CNeditor.js': /^app\/views\/CNeditor/
                'javascripts/vendor.js'  : /^vendor/
                #'test/javascripts/test.js': /^test(\/|\\)(?!vendor)/
                # 'test/javascripts/test-vendor.js': /^test(\/|\\)(?=vendor)/
            order:
                # Files in `vendor` directories are compiled before other files
                # even if they aren't specified in order.
                before: [
                    'vendor/scripts/jquery-1.8.2.js'
                    'vendor/scripts/lodash-v0.8.2.js'
                    'vendor/scripts/backbone-0.9.2.js'
                ]

        stylesheets:
            joinTo:
                'stylesheets/CNeditor.css': /^app\/views\/CNeditor/ # the editor css is seperated in order to use the compiled files in other projects
                'stylesheets/app.css': /(^vendor\/styles)|(^app\/views\/styles)/ # /vendor/sytles or app/views/styles but not /app/views/CNeditor, it would be redundant
                'test/stylesheets/test.css': /^test/

            order:
                before: ['vendor/styles/normalize.css']
                after: ['vendor/styles/helpers.css']

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'

    modules:
        wrapper: false
        definition:  (path, data) ->
            if path == "public/CNeditor.js"
                """
                md2cozy = require('./md2cozy').md2cozy;

                selection = require('./selection').selection;
                """

