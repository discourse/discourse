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

    var self = this;

    var initAce = function() {
      self.editor = ace.edit(self.$('.ace')[0]);
      self.editor.setTheme("ace/theme/chrome");
      self.editor.setShowPrintMargin(false);
      self.editor.getSession().setMode("ace/mode/" + (self.get('mode')));
      self.editor.on("change", function() {
        self.skipContentChangeEvent = true;
        self.set('content', self.editor.getSession().getValue());
        self.skipContentChangeEvent = false;
      });
      self.$().data('editor', self.editor);
    };

    if (window.ace) {
      initAce();
    } else {
      $LAB.script('/javascripts/ace/ace.js').wait(initAce);
    }
  }
});


Discourse.View.registerHelper('aceEditor', Discourse.AceEditorView);
