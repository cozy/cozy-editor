
CNeditor = require('views/CNeditor/CNeditor').CNeditor

exports.test = () -> 
    describe 'Editor', ->

        before (done) ->
            $("body").prepend '<iframe id="editor"></iframe>'

            @editor = new CNeditor $("#editor")[0], ->
               done()

        it "_initClipBoard", ->
            @editor._initClipBoard()
            expect(@editor.clipboard$.attr('id')).to.be('editor-clipboard')
            expect(@editor.editorBody$.find('#editor-clipboard').length).to.be(1)

        it 'getEditorContent - titles', ->
            @editor.linesDiv.innerHTML = '<div id="CNID_1" class="Th-1"><span>Un premier titre</span><br></div><div id="CNID_2" class="Lh-1"><span>Une ligne Lh-1 plutôt longue</span><br></div><div id="CNID_3" class="Th-2"><span>Un second titre</span><br></div><div id="CNID_4" class="Lh-2"><span>Une ligne Lh-2.</span><br></div>'
            expect(@editor.getEditorContent()).to.be """# Un premier titre

    Une ligne Lh-1 plutôt longue

    ## Un second titre

    Une ligne Lh-2."""
            
        it 'setEditorContent - titles', ->
            @editor.setEditorContent """# Un premier titre

    Une ligne Lh-1 plutôt longue

    ## Un second titre

    Une ligne Lh-2."""

            expect(@editor.linesDiv.innerHTML).to.be '<div id="CNID_1" class="Th-1"><span>Un premier titre</span><br></div><div id="CNID_2" class="Lh-1"><span>Une ligne Lh-1 plutôt longue</span><br></div><div id="CNID_3" class="Th-2"><span>Un second titre</span><br></div><div id="CNID_4" class="Lh-2"><span>Une ligne Lh-2.</span><br></div>'


        it 'getEditorContent - bullets', ->
            @html =
                '<div id="CNID_1" class="Th-1"><span>title</span><br></div><div id="CNID_2" class="Tu-2"><span>bullet 1</span><br></div><div id="CNID_3" class="Tu-3"><span>bullet 2</span><br></div><div id="CNID_4" class="Tu-3"><span>bullet 3</span><br></div>'
            @markdown = """# title

    * bullet 1
        * bullet 2
        * bullet 3
    """
            @editor.linesDiv.innerHTML = @html
            expect(@editor.getEditorContent()).to.be @markdown

        it 'setEditorContent - bullets', ->
            @editor.setEditorContent @markdown
            expect(@editor.linesDiv.innerHTML).to.be @html
