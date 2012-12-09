
describe 'Editor', ->

    before (done) ->
        @editor = new CNeditor $("#editor"), ->
            done()

    it "_initClipBoard", ->
        @editor._initClipBoard()
        expect(@editor.clipboard$.attr('id')).to.be('editor-clipboard')
        expect(@editor.editorBody$.find('#editor-clipboard').length).to.be(1)

        #clipboard$.prependTo @editorBody$
        #@clipboard = clipboard$[0]
        #@clipboard.style.setProperty('width','280px')
        #@clipboard.style.setProperty('position','fixed')
        #@clipboard.style.setProperty('overflow','hidden')
        #@clipboard
 
