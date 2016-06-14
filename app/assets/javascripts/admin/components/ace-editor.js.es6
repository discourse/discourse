/* global ace:true */
import loadScript from 'discourse/lib/load-script';
import escapeExpression from 'discourse/lib/utilities';

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
      buffer.push(escapeExpression(this.get('content')));
    }
    buffer.push("</div>");
  },

  _destroyEditor: function() {
    if (this._editor) {
      this._editor.destroy();
      this._editor = null;
    }
    if (this.appEvents) {
      // xxx: don't run during qunit tests
      this.appEvents.off('ace:resize', this, this.resize);
    }
  }.on('willDestroyElement'),

  resize() {
    if (this._editor) {
      this._editor.resize();
    }
  },

  _initEditor: function() {
    const self = this;

    loadScript("/javascripts/ace/ace.js", { scriptTag: true }).then(function() {
      ace.require(['ace/ace'], function(loadedAce) {
        const editor = loadedAce.edit(self.$('.ace')[0]);

        editor.setTheme("ace/theme/chrome");
        editor.setShowPrintMargin(false);
        editor.getSession().setMode("ace/mode/" + self.get('mode'));
        editor.on('change', function() {
          self._skipContentChangeEvent = true;
          self.set('content', editor.getSession().getValue());
          self._skipContentChangeEvent = false;
        });
        editor.$blockScrolling = Infinity;

        self.$().data('editor', editor);
        self._editor = editor;
        if (self.appEvents) {
          // xxx: don't run during qunit tests
          self.appEvents.on('ace:resize', self, self.resize);
        }
      });
    });

  }.on('didInsertElement')
});
