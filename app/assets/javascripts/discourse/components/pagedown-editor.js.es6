import loadScript from 'discourse/lib/load-script';

export default Ember.Component.extend({
  elementId: 'pagedown-editor',

  _initializeWmd: function() {
    const self = this;
    loadScript('defer/html-sanitizer-bundle').then(function() {
      $('#wmd-input').data('init', true);
      self._editor = Discourse.Markdown.createEditor();
      self._editor.run();
      Ember.run.scheduleOnce('afterRender', self, self._refreshPreview);
    });
  }.on('didInsertElement'),

  observeValue: function() {
    Ember.run.scheduleOnce('afterRender', this, this._refreshPreview);
  }.observes('value'),

  _refreshPreview() {
    this._editor.refreshPreview();
  }
});
