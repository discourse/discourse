/*global ace:true */

import loadScript from 'discourse/lib/load-script';

export default Ember.Component.extend({
  mode: 'css',
  classNames: ['ace-wrapper'],
  _editor: null,
  _skipContentChangeEvent: null,

  contentChanged: function() {
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setValue(this.get('content'));
    }
  }.observes('content'),

  render(buffer) {
    buffer.push("<div class='ace'>");
    if (this.get('content')) {
      buffer.push(Handlebars.Utils.escapeExpression(this.get('content')));
    }
    buffer.push("</div>");
  },

  _destroyEditor: function() {
    if (this._editor) {
      this._editor.destroy();
      this._editor = null;
    }
  }.on('willDestroyElement'),

  _initEditor: function() {
    const self = this;

    loadScript("/javascripts/ace/ace.js", { scriptTag: true }).then(function() {
      const editor = ace.edit(self.$('.ace')[0]);

      editor.setTheme("ace/theme/chrome");
      editor.setShowPrintMargin(false);
      editor.getSession().setMode("ace/mode/" + (self.get('mode')));
      editor.on('change', function() {
        self._skipContentChangeEvent = true;
        self.set('content', editor.getSession().getValue());
        self._skipContentChangeEvent = false;
      });

      self.$().data('editor', editor);
      self._editor = editor;
    });

  }.on('didInsertElement')
});
