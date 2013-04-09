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
                '../build/CNeditor.js': /^app\/CNeditor\/.*(\.coffee)|(\.js)$/

                # for deployement directly in cozy-notes
                '../../cozy-notes/client/vendor/scripts/CNeditor.js': /^app\/CNeditor\/.*(\.coffee)|(\.js)$/

                'javascripts/tests.js': /^test/

            order:
                before: [
                    'app/CNeditor/selection.coffee'
                    'app/CNeditor/md2cozy.coffee'
                    'app/CNeditor/task.coffee'
                    'app/CNeditor/realtimer.coffee'                ]
        stylesheets:
            joinTo:
                '../build/CNeditor.css': /^app\/CNeditor/
                '../../cozy-notes/client/vendor/styles/CNeditor.css': /^app\/CNeditor/
            order:
                before:[
                    'app/CNeditor/datepicker.css'
                ]


    modules:
        wrapper: 'commonjs'