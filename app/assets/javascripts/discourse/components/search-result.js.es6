export default Ember.Component.extend({
  tagName: 'ul',

  _highlightOnInsert: function() {
    const term = this.get('controller.term');
    if(!_.isEmpty(term)) {
      this.$('.blurb').highlight(term.split(/\s+/), {className: 'search-highlight'});
      this.$('.topic-title').highlight(term.split(/\s+/), {className: 'search-highlight'} );
    }
  }.on('didInsertElement')
});
