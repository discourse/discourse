/*global ace:true */
(function() {

  /**
    A view that wraps the ACE editor (http://ace.ajax.org/)

    @class AceEditorView    
    @extends Discourse.View
    @namespace Discourse
    @module Discourse
  **/ 
  Discourse.AceEditorView = window.Discourse.View.extend({
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
      var initAce,
        _this = this;
      initAce = function() {
        _this.editor = ace.edit(_this.$('.ace')[0]);
        _this.editor.setTheme("ace/theme/chrome");
        _this.editor.setShowPrintMargin(false);
        _this.editor.getSession().setMode("ace/mode/" + (_this.get('mode')));
        return _this.editor.on("change", function(e) {
          /* amending stuff as you type seems a bit out of scope for now - can revisit after launch
             changes = @get('changes')
             unless changes
               changes = []
               @set('changes', changes)
             changes.push e.data
          */
          _this.skipContentChangeEvent = true;
          _this.set('content', _this.editor.getSession().getValue());
          _this.skipContentChangeEvent = false;
        });
      };
      if (window.ace) {
        return initAce();
      } else {
        return $LAB.script('http://d1n0x3qji82z53.cloudfront.net/src-min-noconflict/ace.js').wait(initAce);
      }
    }
  });

}).call(this);
