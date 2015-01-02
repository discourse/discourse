import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  classNameBindings: ['containerClass'],
  rerenderTriggers: ['condition'],

  containerClass: function() {
    return (this.get('size') === 'small') ? 'inline-spinner' : undefined;
  }.property('size'),

  renderString: function(buffer) {
    if (this.get('condition')) {
      buffer.push('<div class="spinner ' + this.get('size') + '"}}></div>');
    } else {
      return this._super();
    }
  }
});
