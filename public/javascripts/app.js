(function(/*! Brunch !*/) {
  'use strict';

  var globals = typeof window !== 'undefined' ? window : global;
  if (typeof globals.require === 'function') return;

  var modules = {};
  var cache = {};

  var has = function(object, name) {
    return ({}).hasOwnProperty.call(object, name);
  };

  var expand = function(root, name) {
    var results = [], parts, part;
    if (/^\.\.?(\/|$)/.test(name)) {
      parts = [root, name].join('/').split('/');
    } else {
      parts = name.split('/');
    }
    for (var i = 0, length = parts.length; i < length; i++) {
      part = parts[i];
      if (part === '..') {
        results.pop();
      } else if (part !== '.' && part !== '') {
        results.push(part);
      }
    }
    return results.join('/');
  };

  var dirname = function(path) {
    return path.split('/').slice(0, -1).join('/');
  };

  var localRequire = function(path) {
    return function(name) {
      var dir = dirname(path);
      var absolute = expand(dir, name);
      return globals.require(absolute);
    };
  };

  var initModule = function(name, definition) {
    var module = {id: name, exports: {}};
    definition(module.exports, localRequire(name), module);
    var exports = cache[name] = module.exports;
    return exports;
  };

  var require = function(name) {
    var path = expand(name, '.');

    if (has(cache, path)) return cache[path];
    if (has(modules, path)) return initModule(path, modules[path]);

    var dirIndex = expand(path, './index');
    if (has(cache, dirIndex)) return cache[dirIndex];
    if (has(modules, dirIndex)) return initModule(dirIndex, modules[dirIndex]);

    throw new Error('Cannot find module "' + name + '"');
  };

  var define = function(bundle) {
    for (var key in bundle) {
      if (has(bundle, key)) {
        modules[key] = bundle[key];
      }
    }
  }

  globals.require = require;
  globals.require.define = define;
  globals.require.brunch = true;
})();

window.require.define({"initialize": function(exports, require, module) {
  var AutoTest, CNeditor, beautify, cb, editor, editorIframe$;

  require('../lib/app_helpers');

  beautify = require('views/beautify').beautify;

  CNeditor = require('views/CNeditor/CNeditor').CNeditor;

  AutoTest = require('views/autoTest').AutoTest;

  /*****************************************************
   * 0 - INITIALIZE APP
  */


  $("body").html(require('./views/templates/editor'));

  editorIframe$ = $("iframe");

  /*****************************************************
   * 1 - EDITOR CALL BACK
   * 
   * callback to execute after editor's initialization 
   * the contexte (this) inside the function is the editor
  */


  cb = function() {
    /* initialize content of the editor
    this.replaceContent( require('views/templates/content-empty') )
    this.replaceContent( require('views/templates/content-full') )
    this.replaceContent( require('views/templates/content-full-marker') )
    this.replaceContent( require('views/templates/content-shortlines-marker') )
    this.replaceContent( require('views/templates/content-full-relative-indent') )
    this.replaceContent( require('views/templates/content-shortlines-all-hacked') )
    this.deleteContent()
    */

    var addClassToLines, checker, editorBody$, editorCtrler, getSelectedLines, removeClassFromLines,
      _this = this;
    this.replaceContent(require('views/templates/content-shortlines-all'));
    editorCtrler = this;
    editorBody$ = this.editorBody$;
    beautify(editorBody$);
    editorBody$.on('keyup', function() {
      return beautify(editorBody$);
    });
    $("#resultBtnBar_coller").on('click', function() {
      return beautify(editorBody$);
    });
    $("#printRangeBtn").on("click", function() {
      var i, l, range, sel, _results;
      sel = editorCtrler.getEditorSelection();
      i = 0;
      l = sel.rangeCount;
      _results = [];
      while (i < l) {
        console.log("Range N°" + i);
        range = sel.getRangeAt(i);
        console.log(range);
        console.log("content : " + (range.toHtml()));
        _results.push(i++);
      }
      return _results;
    });
    $('#contentSelect').on("change", function(e) {
      console.log("views/templates/" + e.currentTarget.value);
      editorCtrler.replaceContent(require("views/templates/" + e.currentTarget.value));
      return beautify(editorBody$);
    });
    $('#cssSelect').on("change", function(e) {
      return editorCtrler.replaceCSS(e.currentTarget.value);
    });
    $("#indentBtn").on("click", function() {
      return editorCtrler.tab();
    });
    $("#unIndentBtn").on("click", function() {
      return editorCtrler.shiftTab();
    });
    $("#markerListBtn").on("click", function() {
      return editorCtrler.markerList();
    });
    $("#titleBtn").on("click", function() {
      return editorCtrler.titleList();
    });
    $("#clearBtn").on("click", function() {
      return editorCtrler.deleteContent();
    });
    $("#undoBtn").on("click", function() {
      return editorCtrler.unDo();
    });
    $("#redoBtn").on("click", function() {
      return editorCtrler.reDo();
    });
    checker = new AutoTest();
    $("#checkBtn").on("click", function() {
      var date, res, st;
      res = checker.checkLines(editorCtrler);
      date = new Date();
      st = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds() + " - ";
      if (res) {
        return $("#resultText").val(st + "Syntax test success");
      } else {
        return $("#resultText").val(st + "Syntax test FAILLURE : cf logs");
      }
    });
    $("#markdownBtn").on("click", function() {
      return $("#resultText").val(editorCtrler._cozy2md($("#resultText").val()));
    });
    $("#cozyBtn").on("click", function() {
      return $("#resultText").val(editorCtrler._md2cozy($("#resultText").val()));
    });
    $("#addClass").toggle(function() {
      return addClassToLines("sel");
    }, function() {
      return removeClassFromLines("sel");
    });
    getSelectedLines = function(sel) {
      var divs, i, k, myDivs, node, range, _i, _ref;
      myDivs = [];
      if (sel.rangeCount === 0) {
        return;
      }
      for (i = _i = 0, _ref = sel.rangeCount - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        range = sel.getRangeAt(i);
        divs = range.getNodes([1], function(element) {
          return element.nodeName === 'DIV';
        });
        if (divs.length === 0) {
          if (range.commonAncestorContainer.nodeName !== 'BODY') {
            node = range.commonAncestorContainer;
            if (node.nodeName !== 'DIV') {
              node = $(node).parents("div")[0];
            }
            divs.push(node);
          }
        }
        k = 0;
        while (k < divs.length) {
          myDivs.push($(divs[k]));
          k++;
        }
      }
      return myDivs;
    };
    addClassToLines = function(mode) {
      var div, k, lineID, lines, sel, _results, _results1;
      sel = rangy.getIframeSelection(_this.editorIframe);
      if (mode === "sel") {
        lines = getSelectedLines(sel);
        k = 0;
        _results = [];
        while (k < lines.length) {
          div = lines[k];
          div.attr('toDisplay', div.attr('class') + '] ');
          _results.push(k++);
        }
        return _results;
      } else {
        lines = _this._lines;
        _results1 = [];
        for (lineID in lines) {
          div = $(lines[lineID].line$[0]);
          _results1.push(div.attr('toDisplay', div.attr('class') + '] '));
        }
        return _results1;
      }
    };
    removeClassFromLines = function(mode) {
      var div, k, lineID, lines, sel, _results, _results1;
      sel = rangy.getIframeSelection(_this.editorIframe);
      if (mode === "sel") {
        lines = getSelectedLines(sel);
        k = 0;
        _results = [];
        while (k < lines.length) {
          div = lines[k];
          div.attr('toDisplay', '');
          _results.push(k++);
        }
        return _results;
      } else {
        lines = _this._lines;
        _results1 = [];
        for (lineID in lines) {
          div = $(lines[lineID].line$[0]);
          _results1.push(div.attr('toDisplay', ''));
        }
        return _results1;
      }
    };
    $("#addClass2LineBtn").on("click", function() {
      var editor_doAddClasseToLines;
      addClassToLines();
      if (editor_doAddClasseToLines) {
        $("#addClass2LineBtn").html("Show Class on Lines");
        editor_doAddClasseToLines = false;
        editorBody$.off('keyup', addClassToLines);
        return removeClassFromLines();
      } else {
        $("#addClass2LineBtn").html("Hide Class on Lines");
        editor_doAddClasseToLines = true;
        return editorBody$.on('keyup', addClassToLines);
      }
    });
    editorBody$.on("paste", function() {
      return window.setTimeout(function() {
        var date, res, st;
        res = checker.checkLines(editorCtrler);
        date = new Date();
        st = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds() + " - ";
        if (res) {
          return $("#resultText").val(st + "Syntax test success");
        } else {
          return $("#resultText").val(st + "Syntax test FAILLURE : cf logs");
        }
      }, 400);
    });
    return $("#logEditorCtrlerBtn").on("click", function() {
      return console.log(editorCtrler);
    });
  };

  /*****************************************************
   * 3 - creation of the editor
  */


  editor = new CNeditor(document.querySelector('#editorIframe'), cb);
  
}});

window.require.define({"lib/app_helpers": function(exports, require, module) {
  
  (function() {
    return (function() {
      var console, dummy, method, methods, _results;
      console = window.console = window.console || {};
      method = void 0;
      dummy = function() {};
      methods = 'assert,count,debug,dir,dirxml,error,exception,\
                     group,groupCollapsed,groupEnd,info,log,markTimeline,\
                     profile,profileEnd,time,timeEnd,trace,warn'.split(',');
      _results = [];
      while (method = methods.pop()) {
        _results.push(console[method] = console[method] || dummy);
      }
      return _results;
    })();
  })();
  
}});

window.require.define({"views/autoTest": function(exports, require, module) {
  
  exports.AutoTest = (function() {

    function AutoTest() {}

    /* ------------------------------------------------------------------------
    # Checks whether the lines are well structured or not
    # Some suggestions of what could be checked out:
    #    <> each elt of lines corresponds to a DIV ------------------ (OK)
    #    <> each DIV has a matching elt in lines -------------------- (OK)
    #    <> type and depth are coherent ----------------------------- (OK)
    #    <> linePrev and LineNext are linked to the correct DIV ----- (OK)
    #    <> hierarchy of lines and indentation are okay ------------- (OK)
    #    <> a DIV contains a sequence of SPAN ended by a BR --------- (OK)
    #    <> two successive SPAN can't have the same class ----------- (OK)
    #    <> empty SPAN are really empty (<span></span>) ------------- (huh?)
    #    <> a note must  have at least one line --------------------- (todo)
    # BUG? un Tu-6 qui suit un Th-1 n'est pas détecté
    */


    AutoTest.prototype.checkLines = function(CNEditor) {
      var child, children, currentLine, depth, element, i, id, lastClass, myAncestor, newNode, nextLine, node, nodeType, objDiv, possibleSon, prevLine, recVerif, root, rootLine, success, type;
      console.log('Detecting incoherences...');
      possibleSon = {
        "Th": function(name) {
          return name === "Lh" || name === "Th" || name === "To" || name === "Tu";
        },
        "Tu": function(name) {
          return name === "Lu" || name === "To" || name === "Tu";
        },
        "To": function(name) {
          return name === "Lo" || name === "To" || name === "Tu";
        },
        "Lh": function(name) {
          return false;
        },
        "Lu": function(name) {
          return false;
        },
        "Lo": function(name) {
          return false;
        },
        "root": function(name) {
          return true;
        }
      };
      nodeType = function(name) {
        if (name === "Lh" || name === "Lu" || name === "Lo") {
          return "L";
        } else if (name === "Th" || name === "Tu" || name === "To") {
          return "T";
        } else {
          return "ERR";
        }
      };
      id = function(line) {
        if (line === null) {
          return -1;
        } else {
          return parseInt(line.lineID.split("_")[1], 10);
        }
      };
      rootLine = {
        lineType: "root",
        lineID: "CNID_0",
        lineNext: CNEditor._lines["CNID_1"],
        linePrev: null,
        lineDepthAbs: 0
      };
      node = function(line, sons) {
        return {
          line: line,
          sons: sons
        };
      };
      root = new node(rootLine, []);
      myAncestor = [root];
      prevLine = null;
      currentLine = rootLine;
      nextLine = rootLine.lineNext;
      while (nextLine !== null) {
        type = nodeType(nextLine.lineType);
        depth = nextLine.lineDepthAbs;
        element = CNEditor.editorBody$.children("#" + nextLine.lineID);
        if (element === null) {
          console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " has no matching DIV)");
          return;
        }
        children = element.children();
        if (children === null || children.length < 2) {
          console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " content is too short)");
          return;
        }
        lastClass = void 0;
        i = 0;
        while (i < children.length - 1) {
          child = children.get(i);
          if (child.nodeName === 'SPAN') {
            if ($(child).attr('class') != null) {
              if (lastClass === $(child).attr('class')) {
                console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " two consecutive SPAN with same class " + lastClass + ")");
                return;
              } else {
                lastClass = $(child).attr('class');
              }
            }
          } else if (child.nodeName === 'A' || child.nodeName === 'IMG') {
            lastClass = void 0;
          } else {
            console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " invalid label " + child.nodeName + ")");
            return;
          }
          i++;
        }
        child = children.get(children.length - 1);
        if (child.nodeName !== 'BR') {
          console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " must end with BR)");
          return;
        }
        newNode = new node(nextLine, []);
        if (type === "T") {
          if (depth > myAncestor.length) {
            console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " indentation issue)");
            return;
          } else if (depth === myAncestor.length) {
            myAncestor.push(newNode);
          } else {
            myAncestor[depth] = newNode;
          }
          if (myAncestor[depth - 1] === null) {
            console.log("ERROR: invalid line " + nextLine.lineID);
            return;
          } else {
            myAncestor[depth - 1].sons.push(newNode);
          }
        } else if (type === "L") {
          if (depth >= myAncestor.length) {
            console.log("ERROR: invalid line " + nextLine.lineID + "\n (" + nextLine.lineType + "-" + nextLine.lineDepthAbs + " indentation issue)");
            return;
          } else {
            myAncestor[depth + 1] = null;
          }
          if (myAncestor[depth] === null) {
            console.log("ERROR: invalid line " + nextLine.lineID);
            return;
          } else {
            myAncestor[depth].sons.push(newNode);
          }
        }
        prevLine = currentLine;
        currentLine = nextLine;
        nextLine = currentLine.lineNext;
      }
      objDiv = CNEditor.editorBody$.children("div");
      objDiv.each(function() {
        var myId;
        if ($(this).attr('id') != null) {
          myId = $(this).attr('id');
          if (/CNID_[0-9]+/.test(myId)) {
            if (!(CNEditor._lines[myId] != null)) {
              console.log("ERROR: missing line " + myId);
            }
          }
        }
      });
      recVerif = function(node) {
        var _i, _ref;
        if (node.sons.length > 0) {
          for (i = _i = 0, _ref = node.sons.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
            child = node.sons[i];
            if (!possibleSon[node.line.lineType](child.line.lineType)) {
              console.log("ERROR: invalid line " + child.line.lineID + "\n (hierarchic issue of a " + child.line.lineType + "-" + child.line.lineDepthAbs + ")");
              return false;
            }
            if (nodeType(child.line.lineType) === "T") {
              if (node.line.lineDepthAbs + 1 !== child.line.lineDepthAbs) {
                console.log("ERROR: invalid line " + child.line.lineID + "\n (indentation issue of a " + child.line.lineType + "-" + child.line.lineDepthAbs + ")");
                return false;
              }
              if (!recVerif(child)) {
                return false;
              }
            } else if (nodeType(child.line.lineType) === "L") {
              if (node.line.lineDepthAbs !== child.line.lineDepthAbs) {
                console.log("ERROR: invalid line " + child.line.lineID + "\n (indentation issue of a " + child.line.lineType + "-" + child.line.lineDepthAbs + ")");
                return false;
              }
            }
          }
        }
        return true;
      };
      success = recVerif(root);
      if (success) {
        console.log("everything seems ok !");
      }
      return success;
    };

    return AutoTest;

  })();
  
}});

window.require.define({"views/beautify": function(exports, require, module) {
  var any, read_settings_from_cookie, store_settings_to_cookie, the, unpacker_filter;

  any = function(a, b) {
    return a || b;
  };

  read_settings_from_cookie = function() {
    $("#tabsize").val(any($.cookie("tabsize"), "4"));
    $("#brace-style").val(any($.cookie("brace-style"), "collapse"));
    $("#detect-packers").attr("checked", $.cookie("detect-packers") !== "off");
    $("#preserve-newlines").attr("checked", $.cookie("preserve-newlines") !== "off");
    $("#keep-array-indentation").attr("checked", $.cookie("keep-array-indentation") === "on");
    $("#indent-scripts").val(any($.cookie("indent-scripts"), "normal"));
    return $("#space-before-conditional").attr("checked", $.cookie("space-before-conditional") !== "off");
  };

  store_settings_to_cookie = function() {
    var opts;
    opts = {
      expires: 360
    };
    $.cookie("tabsize", $("#tabsize").val(), opts);
    $.cookie("brace-style", $("#brace-style").val(), opts);
    $.cookie("detect-packers", ($("#detect-packers").attr("checked") ? "on" : "off"), opts);
    $.cookie("preserve-newlines", ($("#preserve-newlines").attr("checked") ? "on" : "off"), opts);
    $.cookie("keep-array-indentation", ($("#keep-array-indentation").attr("checked") ? "on" : "off"), opts);
    $.cookie("space-before-conditional", ($("#space-before-conditional").attr("checked") ? "on" : "off"), opts);
    return $.cookie("indent-scripts", $("#indent-scripts").val(), opts);
  };

  unpacker_filter = function(source) {
    var comment, found, trailing_comments, _results;
    trailing_comments = "";
    comment = "";
    found = false;
    _results = [];
    while (true) {
      found = false;
      if (/^\s*\/\*/.test(source)) {
        found = true;
        comment = source.substr(0, source.indexOf("*/") + 2);
        source = source.substr(comment.length).replace(/^\s+/, "");
        trailing_comments += comment + "\n";
      } else if (/^\s*\/\//.test(source)) {
        found = true;
        comment = source.match(/^\s*\/\/.*/)[0];
        source = source.substr(comment.length).replace(/^\s+/, "");
        trailing_comments += comment + "\n";
      }
      if (!found) {
        break;
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  exports.beautify = function(ed$) {
    var brace_style, comment_mark, indent_char, indent_scripts, indent_size, keep_array_indentation, opts, preserve_newlines, source, space_before_conditional;
    if (the.beautify_in_progress) {
      return;
    }
    the.beautify_in_progress = true;
    source = ed$.html();
    indent_size = $("#tabsize").val();
    indent_char = (indent_size === 1 ? "\t" : " ");
    preserve_newlines = $("#preserve-newlines").attr("checked");
    keep_array_indentation = $("#keep-array-indentation").attr("checked");
    indent_scripts = $("#indent-scripts").val();
    brace_style = $("#brace-style").val();
    space_before_conditional = $("#space-before-conditional").attr("checked");
    if ($("#detect-packers").attr("checked")) {
      source = unpacker_filter(source);
    }
    comment_mark = "<-" + "-";
    opts = {
      indent_size: 4,
      indent_char: " ",
      preserve_newlines: true,
      brace_style: "collapse",
      keep_array_indentation: false,
      space_after_anon_function: true,
      space_before_conditional: true,
      indent_scripts: "normal"
    };
    if (source && source[0] === "<" && source.substring(0, 4) !== comment_mark) {
      $("#resultText").val(style_html(source, opts));
    } else {
      $("#resultText").val(js_beautify(unpacker_filter(source), opts));
    }
    return the.beautify_in_progress = false;
  };

  the = {
    beautify_in_progress: false
  };
  
}});

window.require.define({"views/templates/content-empty": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<div id="CNID_1" class="Tu-1"><span></span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/content-full-marker": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<!-- --------------------------------------------><!-- Premier Th-1--><div class="Tu-1"><span>Un premier titre</span><br/></div><div class="Lu-1"><span>Une ligne Lu-1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-2"><span>Un second titre</span><br/></div><div class="Lu-2"><span>Une ligne qui devient un titre après un suppr</span><br/></div><div class="Tu-3"><span>Un troisième titre</span><br/></div><div class="Lu-3"><span>Une ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Lu-3"><span>Une 2ièmle ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-3"><span>Un troisième titre</span><br/></div><div class="Lu-3"><span>Une ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-2"><span>Un second titre</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-3"><span>Un troisième titre</span><br/></div><div class="Lu-3"><span>Une ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-4"><span>Point 1 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Lu-3"><span>Une 2ièmle ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-3"><span>Un troisième titre</span><br/></div><div class="Lu-3"><span>Une ligne Lu-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><!-- --------------------------------------------><!-- Second Tu-1--><div class="Tu-1"><span>Un second Titre Tu-1</span><br/></div><div class="Lu-1"><span>Nous allons maintenant aborder les chapitres à puces :</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-1"><span>Un premier titre</span><br/></div><div class="Lu-1"><span>Une ligne de niveau 1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne </span><br/></div><div class="Lu-1"><span>Une seconde ligne de niveau 1 </span><br/></div><div class="Tu-2"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-2"><span>Un second paragraphe avec un titre long et une ligne, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Lu-2"><span>Ligne du Second paragraphe </span><br/></div><div class="Tu-2"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-3"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-3"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-3"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>3ième paragraphe (1 titre & 2 lignes)</span><br/></div><div class="Lu-3"><span>Ligne 1 du 3ième paragraphe, pas longue.</span><br/></div><div class="Lu-3"><span>Ligne 2 du 3ième paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>Quatrième paragraphe avec une sous liste :</span><br/></div><div class="Tu-4"><span>Premier paragraphe</span><br/></div><div class="Tu-4"><span>Second paragraphe</span><br/></div><div class="Lu-4"><span>Ligne 1 du 2nd paragraphe, pas longue.</span><br/></div><div class="Tu-4"><span>troisième paragraphe</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe</span><br/></div><div class="Tu-1"><span>Un titre de niveau 1</span><br/></div><div class="Tu-2"><span>Un titre de niveau 2</span><br/></div><div class="Tu-3"><span>Un paragraphe un  titre et deux lignes</span><br/></div><div class="Lu-3"><span>Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Lu-3"><span>Seconde ligne, pas très longue.</span><br/></div><div class="Tu-2"><span>Un second titre de niveau 2</span><br/></div><div class="Lu-2"><span>Ligne commentant le paragraphe</span><br/></div><div class="Lu-2"><span>Seconde ligne commentant le paragraphe</span><br/></div><div class="Tu-3"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-3"><span>Un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Tu-3"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-4"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-4"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-4"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-4"><span></span><br/></div><div class="Tu-4"><span>c\'était un paragraphe vide :-)</span><br/></div><div class="Tu-4"><span>12</span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/content-full-relative-indent": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<div id="nav"><div class="Th-1"><span>Un premier titre</span><br/></div><div class="Th-1"><span>Un second titre</span><br/></div><div class="Th-2"><span>Un titre de niveau 2</span><br/></div><div class="Th-2"><span>Un titre de niveau 2</span></div></div><!-- --------------------------------------------><!-- Premier Th-1--><div class="Th-1"><span>Un premier titre</span><br/></div><div class="Lh-1"><span>Une ligne Lh-1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-2"><span>Un second titre</span><br/></div><div class="Lh-2"><span>Une ligne Lh-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Lh-3"><span>Une 2ièmle ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-2"><span>Un second titre</span><br/></div><div class="Lh-2"><span>Une ligne Lh-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-4"><span>Point 1 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Lh-3"><span>Une 2ièmle ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><!-- --------------------------------------------><!-- Second Th-1--><div class="Th-1"><span>Un second Titre Th-1</span><br/></div><div class="Lh-1"><span>Nous allons maintenant aborder les chapitres à puces :</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Th-1"><span>Un premier titre</span><br/></div><div class="Lh-1"><span>Une ligne de niveau 1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne </span><br/></div><div class="Lh-1"><span>Une seconde ligne de niveau 1 </span><br/></div><div class="Tu-2"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-2"><span>Un second paragraphe avec un titre long et une ligne, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Lu-2"><span>Ligne du Second paragraphe </span><br/></div><div class="Tu-2"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-3"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-3"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-3"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>3ième paragraphe (1 titre & 2 lignes)</span><br/></div><div class="Lu-3"><span>Ligne 1 du 3ième paragraphe, pas longue.</span><br/></div><div class="Lu-3"><span>Ligne 2 du 3ième paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>Quatrième paragraphe avec une sous liste :</span><br/></div><div class="Tu-4"><span>Premier paragraphe</span><br/></div><div class="Tu-4"><span>Second paragraphe</span><br/></div><div class="Lu-4"><span>Ligne 1 du 2nd paragraphe, pas longue.</span><br/></div><div class="Tu-4"><span>troisième paragraphe</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe</span><br/></div><div class="Th-1"><span>Un titre de niveau 1</span><br/></div><div class="Th-2"><span>Un titre de niveau 2</span><br/></div><div class="Tu-3"><span>Un paragraphe un  titre et deux lignes</span><br/></div><div class="Lu-3"><span>Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Lu-3"><span>Seconde ligne, pas très longue.</span><br/></div><div class="Th-2"><span>Un second titre de niveau 2</span><br/></div><div class="Lh-2"><span>Ligne commentant le paragraphe</span><br/></div><div class="Lh-2"><span>Seconde ligne commentant le paragraphe</span><br/></div><div class="Tu-3"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-3"><span>Un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Tu-3"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-4"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-4"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-4"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-4"><span></span><br/></div><div class="Tu-4"><span>c\'était un paragraphe vide :-)</span><br/></div><div class="Tu-4"><span>12</span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/content-full": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<!-- --------------------------------------------><!-- Premier Th-1--><div class="Th-1"><span>Un premier titre</span><br/></div><div class="Lh-1"><span>Une ligne Lh-1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-2"><span>Un second titre</span><br/></div><div class="Lh-2"><span>Une ligne Lh-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Lh-3"><span>Une 2ièmle ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-2"><span>Un second titre</span><br/></div><div class="Lh-2"><span>Une ligne Lh-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Tu-4"><span>Point 1 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Tu-4"><span>Point 2 blabla</span><br/></div><div class="Lh-3"><span>Une 2ièmle ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><div class="Th-3"><span>Un troisième titre</span><br/></div><div class="Lh-3"><span>Une ligne Lh-3 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue.</span><br/></div><!-- --------------------------------------------><!-- Second Th-1--><div class="Th-1"><span>Un second Titre Th-1</span><br/></div><div class="Lh-1"><span>Nous allons maintenant aborder les chapitres à puces :</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Tu-2"><span>Second paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-2"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-3"><span>troisième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-3"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe à puce avec un titre et une ligne</span><br/></div><div class="Lu-4"><span>Une ligne Lu-2 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne.</span><br/></div><div class="Th-1"><span>Un premier titre</span><br/></div><div class="Lh-1"><span>Une ligne de niveau 1 plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne plutôt longue pour voir où se situe le retour à la ligne </span><br/></div><div class="Lh-1"><span>Une seconde ligne de niveau 1 </span><br/></div><div class="Tu-2"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-2"><span>Un second paragraphe avec un titre long et une ligne, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Lu-2"><span>Ligne du Second paragraphe </span><br/></div><div class="Tu-2"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-3"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-3"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-3"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>3ième paragraphe (1 titre & 2 lignes)</span><br/></div><div class="Lu-3"><span>Ligne 1 du 3ième paragraphe, pas longue.</span><br/></div><div class="Lu-3"><span>Ligne 2 du 3ième paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-3"><span>Quatrième paragraphe avec une sous liste :</span><br/></div><div class="Tu-4"><span>Premier paragraphe</span><br/></div><div class="Tu-4"><span>Second paragraphe</span><br/></div><div class="Lu-4"><span>Ligne 1 du 2nd paragraphe, pas longue.</span><br/></div><div class="Tu-4"><span>troisième paragraphe</span><br/></div><div class="Tu-4"><span>Quatrième paragraphe</span><br/></div><div class="Th-1"><span>Un titre de niveau 1</span><br/></div><div class="Th-2"><span>Un titre de niveau 2</span><br/></div><div class="Tu-3"><span>Un paragraphe un  titre et deux lignes</span><br/></div><div class="Lu-3"><span>Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Lu-3"><span>Seconde ligne, pas très longue.</span><br/></div><div class="Th-2"><span>Un second titre de niveau 2</span><br/></div><div class="Lh-2"><span>Ligne commentant le paragraphe</span><br/></div><div class="Lh-2"><span>Seconde ligne commentant le paragraphe</span><br/></div><div class="Tu-3"><span>Un paragraphe avec juste un titre</span><br/></div><div class="Tu-3"><span>Un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long, un second paragraphe avec un titre long !</span><br/></div><div class="Tu-3"><span>Un troisième paragraphe avec une liste en dessous :</span><br/></div><div class="Tu-4"><span>Premier paragraphe (1 titre seul)</span><br/></div><div class="Tu-4"><span>Second paragraphe (1 titre & une ligne)</span><br/></div><div class="Lu-4"><span>Ligne du Second paragraphe (1 titre & une ligne), longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs, Très longue ligne mais avec des variations de longueurs.</span><br/></div><div class="Tu-4"><span></span><br/></div><div class="Tu-4"><span>c\'était un paragraphe vide :-)</span><br/></div><div class="Tu-4"><span>12</span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/content-shortlines-all": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<div id="CNID_1" class="Th-1"><span>Tu-1 - n°1</span><br/></div><div id="CNID_2" class="Lh-1"><span>Lh-1 - n°2</span><br/></div><div id="CNID_3" class="Th-2"><span>Th-2 - n°3</span><br/></div><div id="CNID_4" class="Lh-2"><span>Lh-2 - n°4</span><br/></div><div id="CNID_5" class="Tu-3"><span>Tu-3 - n°5</span><br/></div><div id="CNID_6" class="Lu-3"><span>Lu-3 - n°6</span><br/></div><div id="CNID_7" class="Lu-3"><span>Lu-3 - n°7</span><br/></div><div id="CNID_8" class="Tu-3"><span>Tu-3 - n°8</span><br/></div><div id="CNID_9" class="Lu-3"><span>Lu-3 - n°9</span><br/></div><div id="CNID_10" class="Th-2"><span>Th-2 - n°10</span><br/></div><div id="CNID_11" class="Lh-2"><span>Lh-2 - n°11</span><br/></div><div id="CNID_12" class="Th-3"><span>Th-3 - n°12</span><br/></div><div id="CNID_13" class="Lh-3"><span>Lh-3 - n°13</span><br/></div><div id="CNID_14" class="Th-4"><span>Th-4 - n°14</span><br/></div><div id="CNID_15" class="Th-4"><span>Th-4 - n°15</span><br/></div><div id="CNID_16" class="Th-4"><span>Th-4 - n°16</span><br/></div><div id="CNID_17" class="Lh-3"><span>Lh-3 - n°17</span><br/></div><div id="CNID_18" class="Th-3"><span>Th-3 - n°18</span><br/></div><div id="CNID_19" class="Lh-3"><span>Lh-3 - n°19</span><br/></div><div id="CNID_20" class="Th-1"><span>Th-1 - n°20</span><br/></div><div id="CNID_21" class="Lh-1"><span>Lh-1 - n°21</span><br/></div><div id="CNID_22" class="Tu-2"><span>Tu-2 - n°22</span><br/></div><div id="CNID_23" class="Lu-2"><span>Lu-2 - n°23</span><br/></div><div id="CNID_24" class="Tu-3"><span>Tu-3 - n°24</span><br/></div><div id="CNID_25" class="Lu-3"><span>Lu-3 - n°25</span><br/></div><div id="CNID_26" class="Tu-4"><span>Tu-4 - n°26</span><br/></div><div id="CNID_27" class="Lu-4"><span>Lu-4 - n°27</span><br/></div><div id="CNID_28" class="Tu-4"><span>Tu-4 - n°28</span><br/></div><div id="CNID_29" class="Tu-3"><span>Tu-3 - n°29</span><br/></div><div id="CNID_30" class="Lu-3"><span>Lu-3 - n°30</span><br/></div><div id="CNID_31" class="Tu-3"><span>Tu-3 - n°31</span><br/></div><div id="CNID_32" class="Tu-3"><span>Tu-3 - n°32</span><br/></div><div id="CNID_33" class="Tu-3"><span>Tu-3 - n°33</span><br/></div><div id="CNID_34" class="Tu-2"><span>Tu-2 - n°34</span><br/></div><div id="CNID_35" class="Lu-2"><span>Lu-2 - n°35</span><br/></div><div id="CNID_36" class="Tu-3"><span>Tu-3 - n°36</span><br/></div><div id="CNID_37" class="Lu-3"><span>Lu-3 - n°37</span><br/></div><div id="CNID_38" class="Tu-4"><span>Tu-4 - n°38</span><br/></div><div id="CNID_39" class="Lu-4"><span>Lu-4 - n°39</span><br/></div><div id="CNID_40" class="Th-1"><span>Th-1 - n°40</span><br/></div><div id="CNID_41" class="Lh-1"><span>Lh-1 - n°41</span><br/></div><div id="CNID_42" class="Lh-1"><span>Lh-1 - n°42</span><br/></div><div id="CNID_43" class="Tu-2"><span>Tu-2 - n°43</span><br/></div><div id="CNID_44" class="Tu-2"><span>Tu-2 - n°44</span><br/></div><div id="CNID_45" class="Lu-2"><span>Lu-2 - n°45</span><br/></div><div id="CNID_46" class="Tu-2"><span>Tu-2 - n°46</span><br/></div><div id="CNID_47" class="Tu-3"><span>Tu-3 - n°47</span><br/></div><div id="CNID_48" class="Tu-3"><span>Tu-3 - n°48</span><br/></div><div id="CNID_49" class="Lu-3"><span>Lu-3 - n°49</span><br/></div><div id="CNID_50" class="Tu-3"><span>Tu-3 - n°50</span><br/></div><div id="CNID_51" class="Lu-3"><span>Lu-3 - n°51</span><br/></div><div id="CNID_52" class="Lu-3"><span>Lu-3 - n°52</span><br/></div><div id="CNID_53" class="Tu-3"><span>Tu-3 - n°53</span><br/></div><div id="CNID_54" class="Tu-4"><span>Tu-4 - n°54</span><br/></div><div id="CNID_55" class="Tu-4"><span>Tu-4 - n°55</span><br/></div><div id="CNID_56" class="Lu-4"><span>Lu-4 - n°56</span><br/></div><div id="CNID_57" class="Tu-4"><span>Tu-4 - n°57</span><br/></div><div id="CNID_58" class="Tu-4"><span>Tu-4 - n°58</span><br/></div><div id="CNID_59" class="Th-1"><span>Th-1 - n°59</span><br/></div><div id="CNID_60" class="Tu-2"><span>Tu-2 - n°60</span><br/></div><div id="CNID_61" class="Tu-3"><span>Tu-3 - n°61</span><br/></div><div id="CNID_62" class="Lu-3"><span>Lu-3 - n°62</span><br/></div><div id="CNID_63" class="Lu-3"><span>Lu-3 - n°63</span><br/></div><div id="CNID_64" class="Tu-2"><span>Tu-2 - n°64</span><br/></div><div id="CNID_65" class="Lu-2"><span>Lu-2 - n°65</span><br/></div><div id="CNID_66" class="Lu-2"><span>Lu-2 - n°66</span><br/></div><div id="CNID_67" class="Tu-3"><span>Tu-3 - n°67</span><br/></div><div id="CNID_68" class="Tu-3"><span>Tu-3 - n°68</span><br/></div><div id="CNID_69" class="Tu-3"><span>Tu-3 - n°69</span><br/></div><div id="CNID_70" class="Tu-4"><span>Tu-4 - n°70</span><br/></div><div id="CNID_71" class="Tu-4"><span>Tu-4 - n°71</span><br/></div><div id="CNID_72" class="Lu-4"><span>Lu-4 - n°72</span><br/></div><div id="CNID_73" class="Tu-4"><span>Tu-4 - n°73</span><br/></div><div id="CNID_74" class="Tu-4"><span>Tu-4 - n°74</span><br/></div><div id="CNID_75" class="Tu-4"><span>Tu-4 - n°75</span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/content-shortlines-marker": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<!-- --------------------------------------------><!-- Premier Th-1--><!-- //Tu-2  -   n°3--><div class="Tu-1"><span>Tu-1  -   n°1</span><br/></div><div class="Lu-1"><span>Lu-1  -   n°2</span><br/></div><div class="Tu-2"><span></span><br/></div><div class="Lu-2"><span>Lu-2  -   n°4</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°5</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°6</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°7</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°8</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°9</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°10</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°11</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°12</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°13</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°14</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°15</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°16</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°17</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°18</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°19</span><br/></div><!-- --------------------------------------------><!-- Second Tu-1--><div class="Tu-1"><span>Tu-1  -   n°20</span><br/></div><div class="Lu-1"><span>Lu-1  -   n°21</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°22</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°23</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°24</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°25</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°26</span><br/></div><div class="Lu-4"><span>Lu-4  -   n°27</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°28</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°29</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°30</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°31</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°32</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°33</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°34</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°35</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°36</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°37</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°38</span><br/></div><div class="Lu-4"><span>Lu-4  -   n°39</span><br/></div><div class="Tu-1"><span>Tu-1  -   n°40</span><br/></div><div class="Lu-1"><span>Lu-1  -   n°41</span><br/></div><div class="Lu-1"><span>Lu-1  -   n°42</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°43</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°44</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°45</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°46</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°47</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°48</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°49</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°50</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°51</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°52</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°53</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°54</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°55</span><br/></div><div class="Lu-4"><span>Lu-4  -   n°56</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°57</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°58</span><br/></div><div class="Tu-1"><span>Tu-1  -   n°59</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°60</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°61</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°62</span><br/></div><div class="Lu-3"><span>Lu-3  -   n°63</span><br/></div><div class="Tu-2"><span>Tu-2  -   n°64</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°65</span><br/></div><div class="Lu-2"><span>Lu-2  -   n°66</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°67</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°68</span><br/></div><div class="Tu-3"><span>Tu-3  -   n°69</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°70</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°71</span><br/></div><div class="Lu-4"><span>Lu-4  -   n°72</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°73</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°74</span><br/></div><div class="Tu-4"><span>Tu-4  -   n°75</span><br/></div>');
  }
  return buf.join("");
  };
}});

window.require.define({"views/templates/editor": function(exports, require, module) {
  module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
  attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
  var buf = [];
  with (locals || {}) {
  var interp;
  buf.push('<div id="main" class="table-ly-wrpr"><!-- boutons for the editor--><div id="divMainBtn" class="table-ly-hder"><div id="generalBtnBar" class="btn-group"><button id="logKeysBtn" class="btn btn-small btn-primary">Log keystrokes</button><button id="printRangeBtn" class="btn btn-small btn-primary">Print Range</button><button id="addClass" class="btn btn-small btn-primary">Class of selected Lines</button><button id="addClass2LineBtn" class="btn btn-small btn-primary">Show Class on Lines</button><button id="record-button" class="btn btn-small btn-warning">Record</button></div><select id="contentSelect"><option value="content-full" style="display:block">Full note</option><option value="content-full-marker" style="display:block">Tout en puces</option><option value="content-shortlines-marker" style="display:block">Tout en puce, lignes courtes</option><option value="content-shortlines-all" style="display:block">Puces et titres, lignes courtes</option><option value="content-empty" style="display:block">Empty note</option><option value="content-full-relative-indent" style="display:block">Avec sommaire</option><option value="test_1" style="display:block">Test numero 1</option><option value="test_2" style="display:block">Test numero 2</option><option value="test_3" style="display:block">Test numero 3</option><option value="test_4" style="display:block">Test numero 4</option><option value="test_5" style="display:block">Test numero 5</option><option value="test_6" style="display:block">Test numero 6</option><option value="test_7" style="display:block">Test numero 7</option><option value="test_8" style="display:block">Test numero 8</option><option value="test_9" style="display:block">Test numero 9</option><option value="test_10" style="display:block">Test numero 10</option><option value="test_11" style="display:block">Test numero 11</option></select><select id="cssSelect"><option value="images/editor2.css" style="display:block">css1</option><option value="stylesheets/app.css" style="display:block">css2</option><option value="stylesheets/app-deep-1.css" style="display:block">depth_1</option><option value="stylesheets/app-deep-2.css" style="display:block">depth_2</option><option value="stylesheets/app-deep-3.css" style="display:block">depth_3</option><option value="stylesheets/app-deep-4.css" style="display:block">depth_4</option></select></div><div id="main-div" class="table-ly-ctnt"><div id="col-wrap"><div id="editor-col"><div id="well-editor" class="monWell"><div id="editorDiv" class="table-ly-wrpr"><!-- boutons for the editor--><div class="table-ly-hder"><div id="editorBtnBar" class="btn-group"><button id="indentBtn" class="btn btn-small btn-primary">Indent</button><button id="unIndentBtn" class="btn btn-small btn-primary">Un-indent</button><button id="markerListBtn" class="btn btn-small btn-primary">- Marker list</button><button id="titleBtn" class="btn btn-small btn-primary">1.1.2 Title</button><button id="clearBtn" class="btn btn-small btn-primary">Clear</button><button id="undoBtn" class="btn btn-small btn-primary">undo</button><button id="redoBtn" class="btn btn-small btn-primary">redo</button></div></div><!-- text for the editor--><div id="editorContent" class="table-ly-ctnt"><iframe id="editorIframe"></iframe></div></div></div></div><div id="result-col"><div id="well-result" class="monWell"><div id="resultDiv" class="table-ly-wrpr"><div class="table-ly-hder"><div id="resultBtnBar" class="btn-group"><button id="resultBtnBar_coller" class="btn btn-small btn-primary">Coller</button><button id="markdownBtn" class="btn btn-small btn-primary">Convert to Markdown</button><button id="cozyBtn" class="btn btn-small btn-primary">Convert to Cozy</button><button id="checkBtn" class="btn btn-small btn-primary">Run syntax test</button><button id="summaryBtn" class="btn btn-small btn-primary">Display Summary</button></div></div><!-- text for the resulting html--><div id="resultContent" class="table-ly-ctnt"><textarea id="resultText"></textarea></div></div></div></div></div></div></div>');
  }
  return buf.join("");
  };
}});

