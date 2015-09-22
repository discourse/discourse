export default Ember.Component.extend({
  classNameBindings: ['containerClass', 'condition:visible'],

  containerClass: function() {
    return this.get('size') === 'small' ? 'inline-spinner' : undefined;
  }.property('size'),

  render: function(buffer) {
    if (this.get('condition')) {
      buffer.push('<div class="spinner ' + this.get('size') + '"}}></div>');
    } else {
      return this._super(buffer);
    }
  },

  _conditionChanged: function() {
    this.rerender();
  }.observes('condition')
});
