export default Ember.Component.extend({
  tagName: 'span',

  _highlightOnInsert: function() {
    const term = this.get('highlight');
    const self = this;

    if(!_.isEmpty(term)) {
      self.$().highlight(term.split(/\s+/), {className: 'search-highlight'});
    }
  }.observes('highlight').on('didInsertElement')

});
