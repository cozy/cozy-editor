
describe 'Editor', ->

    before (done) ->
        $.get 'ajax/test.html', (data) ->
            $('#result').html(data)
            alert('Load was performed.')
            done()

        # $("body").append '<iframe id="editor"></iframe>'

        # @editor = new CNeditor $("#editor")[0], ->
        #     done()

    it "_initClipBoard", ->
        @editor._initClipBoard()
        expect(@editor.clipboard$.attr('id')).to.be('editor-clipboard')
        expect(@editor.editorBody$.find('#editor-clipboard').length).to.be(1)

    it '_deleteMultiLinesSelections', ->
        @editor._deleteMultiLinesSelections null, null
