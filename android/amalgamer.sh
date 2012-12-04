#!/bin/sh

if ! [ -d "bin" ] ; then
	mkdir bin
fi

if [ $# -gt 0 ] ; then
	dom_element=$1
else
	dom_element="editorIframe"
fi

# Replace a line of editor.coffee
cat ../app/views/editor.coffee | sed -e 's/class exports.CNEditor extends Backbone.View/class CNEditor/g' > modified_editor.coffee

# Replace the stylesheet reference for the editor
cat modified_editor.coffee | sed -e 's/stylesheets\/app.css/editor.css/g' > amalgamed.coffee

# Add a function that constructs an editor in the chosen element
echo "" >> amalgamed.coffee
echo "" >> amalgamed.coffee
echo "cb = () -> this.deleteContent()" >> amalgamed.coffee
echo "editor = new CNEditor( document.getElementById('"$dom_element"'), cb)" >> amalgamed.coffee

stylus ../app/styles/editor.styl && mv ../app/styles/editor.css .

coffee -c amalgamed.coffee

cat ../vendor/scripts/jquery-1.7.1.js ../vendor/scripts/rangy-core.js ../vendor/scripts/rangy-selectionsaverestore-uncompressed.js ../vendor/scripts/showdown.js amalgamed.js > bin/amalgam.js

rm -f modified_editor.coffee amalgamed.js amalgamed.coffee

