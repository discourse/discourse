import loadScript from 'discourse/lib/load-script';
import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  mode: 'css',
  classNames: ['ace-wrapper'],
  _editor: null,
  _skipContentChangeEvent: null,

  @observes('content')
  contentChanged() {
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setValue(this.get('content'));
    }
  },

  @observes('mode')
  modeChanged() {
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setMode("ace/mode/" + this.get('mode'));
    }
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

  didInsertElement() {
    this._super();

    loadScript("/javascripts/ace/ace.js", { scriptTag: true }).then(() => {
      window.ace.require(['ace/ace'], loadedAce => {
        if (!this.element || this.isDestroying || this.isDestroyed) { return; }
        const editor = loadedAce.edit(this.$('.ace')[0]);

        editor.setTheme("ace/theme/chrome");
        editor.setShowPrintMargin(false);
        editor.setOptions({fontSize: "14px"});
        editor.getSession().setMode("ace/mode/" + this.get('mode'));
        editor.on('change', () => {
          this._skipContentChangeEvent = true;
          this.set('content', editor.getSession().getValue());
          this._skipContentChangeEvent = false;
        });
        editor.$blockScrolling = Infinity;

        this.$().data('editor', editor);
        this._editor = editor;
        if (this.appEvents) {
          // xxx: don't run during qunit tests
          this.appEvents.on('ace:resize', self, self.resize);
        }
      });
    });
  }
});
