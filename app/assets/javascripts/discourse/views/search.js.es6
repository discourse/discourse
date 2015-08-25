export default Ember.View.extend({
  tagName: 'div',
  classNames: ['d-dropdown'],
  elementId: 'search-dropdown',
  templateName: 'search',
  keyDown: function(e){
    var term = this.get('controller.term');
    if (e.which === 13 && term && term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.get('controller').send('fullSearch');
    }
  }
});
