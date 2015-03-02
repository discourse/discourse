export default Ember.Component.extend({
  _setupUrls: function() {
    const value = this.get('value');
    this.set('urls', (value && value.length) ? value.split("\n") : []);
  }.on('init').observes('value'),

  _urlsChanged: function() {
    this.set('value', this.get('urls').join("\n"));
  }.observes('urls.@each'),

  urlInvalid: Ember.computed.empty('newUrl'),

  keyDown(e) {
    if (e.keyCode === 13) {
      this.send('addUrl');
    }
  },

  actions: {
    addUrl() {
      if (this.get('urlInvalid')) { return; }

      this.get('urls').addObject(this.get('newUrl'));
      this.set('newUrl', '');
    },

    removeUrl(url) {
      const urls = this.get('urls');
      urls.removeObject(url);
    }
  }
});
