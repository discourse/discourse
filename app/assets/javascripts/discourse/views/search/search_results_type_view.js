(function() {

  window.Discourse.SearchResultsTypeView = Ember.CollectionView.extend({
    tagName: 'ul',
    itemViewClass: Ember.View.extend({
      tagName: 'li',
      templateName: (function() {
        return "search/" + (this.get('parentView.type')) + "_result";
      }).property('parentView.type'),
      classNameBindings: ['selectedClass', 'parentView.type'],
      selectedIndexBinding: 'parentView.parentView.selectedIndex',
      /* Is this row currently selected by the keyboard?
      */

      selectedClass: (function() {
        if (this.get('content.index') === this.get('selectedIndex')) {
          return 'selected';
        }
        return null;
      }).property('selectedIndex')
    })
  });

}).call(this);
