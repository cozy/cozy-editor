undefined
describe('Editor', function() {
  before(function(done) {
    $("body").append('<div id="editor"></div>');
    return this.editor = new CNeditor($("#editor"), function() {
      return done();
    });
  });
  return it("_initClipBoard", function() {
    this.editor._initClipBoard();
    expect(this.editor.clipboard$.attr('id')).to.be('editor-clipboard');
    return expect(this.editor.editorBody$.find('#editor-clipboard').length).to.be(1);
  });
});
