import { observes, on } from 'ember-addons/ember-computed-decorators';
import loadScript from 'discourse/lib/load-script';

export default Ember.Component.extend({
  classNameBindings: [':pagedown-editor'],

  @on("didInsertElement")
  _initializeWmd() {
    loadScript('defer/html-sanitizer-bundle').then(() => {
      this.$('.wmd-input').data('init', true);
      this._editor = Discourse.Markdown.createEditor({ containerElement: this.element });
      this._editor.run();
      Ember.run.scheduleOnce('afterRender', this, this._refreshPreview);
    });
  },

  @observes("value")
  observeValue() {
    Ember.run.scheduleOnce('afterRender', this, this._refreshPreview);
  },

  _refreshPreview() {
    this._editor.refreshPreview();
  }
});
