export default Ember.Component.extend({
  classNameBindings: [':value-list'],

  _setupCollection: function() {
    const values = this.get('values');
    this.set('collection', (values && values.length) ? values.split("\n") : []);
  }.on('init').observes('values'),

  _collectionChanged: function() {
    this.set('values', this.get('collection').join("\n"));
  }.observes('collection.@each'),

  inputInvalid: Ember.computed.empty('newValue'),

  keyDown(e) {
    if (e.keyCode === 13) {
      this.send('addValue');
    }
  },

  actions: {
    addValue() {
      if (this.get('inputInvalid')) { return; }

      this.get('collection').addObject(this.get('newValue'));
      this.set('newValue', '');
    },

    removeValue(value) {
      const collection = this.get('collection');
      collection.removeObject(value);
    }
  }
});
