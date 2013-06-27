/*global ace:true */

/**
  A view that wraps the ACE editor (http://ace.ajax.org/)

  @class AceEditorView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.AceEditorView = Discourse.View.extend({
  mode: 'css',
  classNames: ['ace-wrapper'],

  contentChanged: (function() {
    if (this.editor && !this.skipContentChangeEvent) {
      return this.editor.getSession().setValue(this.get('content'));
    }
  }).observes('content'),

  render: function(buffer) {
    buffer.push("<div class='ace'>");
    if (this.get('content')) {
      buffer.push(Handlebars.Utils.escapeExpression(this.get('content')));
    }
    return buffer.push("</div>");
  },

  willDestroyElement: function() {
    if (this.editor) {
      this.editor.destroy();
      this.editor = null;
    }
  },

  didInsertElement: function() {

    var aceEditorView = this;

    var initAce = function() {
      aceEditorView.editor = ace.edit(aceEditorView.$('.ace')[0]);
      aceEditorView.editor.setTheme("ace/theme/chrome");
      aceEditorView.editor.setShowPrintMargin(false);
      aceEditorView.editor.getSession().setMode("ace/mode/" + (aceEditorView.get('mode')));
      aceEditorView.editor.on("change", function(e) {
        aceEditorView.skipContentChangeEvent = true;
        aceEditorView.set('content', aceEditorView.editor.getSession().getValue());
        aceEditorView.skipContentChangeEvent = false;
      });
    };

    if (window.ace) {
      initAce();
    } else {
      $LAB.script('/javascripts/ace/ace.js').wait(initAce);
    }
  }
});


Discourse.View.registerHelper('aceEditor', Discourse.AceEditorView);
