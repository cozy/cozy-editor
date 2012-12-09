
describe 'Editor', ->

    before (done) ->
        $("body").append '<div id="editor"></div>'

        @editor = new CNeditor $("#editor"), ->
            done()

    it "_initClipBoard", ->
        @editor._initClipBoard()
        expect(@editor.clipboard$.attr('id')).to.be('editor-clipboard')
        expect(@editor.editorBody$.find('#editor-clipboard').length).to.be(1)
