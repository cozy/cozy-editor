
function deleteContentAndroid() {
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.deleteContent() ;
}

function indentation () {
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.tab() ;
}

function unindentation () {
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.shiftTab() ;
}	

function markerListAndroid() {
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.markerList() ;
}

function titleListAndroid() {
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.titleList() ;
}
 
function getEditorContentAndroid() {  //TODO pour la récupération du texte seul cett fonction a été écrite
	var editorBody$  = $("#__ed-iframe-body") ;
	var editorCtrler = editorBody$.prop( '__editorCtl') ;
	editorCtrler.getEditorContent() ;
 }