# Welcome to the fabulous CozyNote Editor

Simple, yet Powerfull : one day it will be !

## Build
* for production :
    + `cd inTheFolder`
    + `npm install` (1st time only of course)
    + `brunch build -o -c config-prod.coffee`
    + `js & css are in ./build`
* for developement :
    + `cd server-test`
    + `npm install` (1st time only of course)
    + `coffee server-test.coffee`
    + `cd ..`
    + `brunch w`
    + code...
    + open localhost:3000 in your browser

## How to use
* put in your project the js and css that are in /build
* get the dependencies and add them to your project :
    * [Jquery](http://jquery.com/): V1.8.2 :
    * [showdown](https://github.com/coreyti/showdown) : V0.3.1 : A javascript port of Markdown - WILL BE REMOVED - KEPT ONLY FOR REVERSE COMPATIBILITY FOR A WILE.
    * [rangy](http://code.google.com/p/rangy/) : V1.2.3 : a librairie that manages ranges and selection. Two modules are required : Rangy core and the Selection save and restore module.
* to create a new editor in an iframe :
    * `var myNewEditor = new CNeditor(iFrameRef,callBack)`
    * where iframeRef is a ref to the iframe where you will embed your editor and callback is the ... callback to run after init of the editor (execution context of callback is the editor itself).

## The main object CNEditor

* Public methods :
    * constructor(iframeTarget, callBack) : the editor is set within the specified iframe label.
    * getEditorContent() : as expected, return the editor content (raw html)
    * setEditorContent(htmlContent) : same here... change the editor content
    * unDo() : ctrl-z
    * reDo() : ctrl-y
    * tab()  : tab
    * and a lot more...
* Events
    * onChange is triggered on the iframe nesting the editor whenever a content's modification occurs. The editor's content should be saved when it happens.


## About the Android/ folder - TO BE UPDATED WHEN ANDROID WILL BE ON THE AGENDA

* run `sh amalgamer.sh [<targetNameHere>]` to generate a JavaScript file that
  nestes an editor inside the element whose id is `<targetNameHere\>` or
  'editorIframe' if no argument specified.

* notice that target may not be an iFrame

