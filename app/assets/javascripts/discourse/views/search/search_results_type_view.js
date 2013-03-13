/**
  This view handles the rendering of search results

  @class SearchResultsTypeView
  @extends Ember.CollectionView
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchResultsTypeView = Ember.CollectionView.extend({
  tagName: 'ul',
  itemViewClass: Ember.View.extend({
    tagName: 'li',
    classNameBindings: ['selectedClass', 'parentView.type'],
    selectedIndexBinding: 'parentView.parentView.selectedIndex',

    templateName: (function() {
      return "search/" + (this.get('parentView.type')) + "_result";
    }).property('parentView.type'),

    // Is this row currently selected by the keyboard?
    selectedClass: (function() {
      if (this.get('content.index') === this.get('selectedIndex')) return 'selected';
      return null;
    }).property('selectedIndex')

  })
});


