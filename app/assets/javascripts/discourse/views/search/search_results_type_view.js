/**
  This view handles the rendering of search results

  @class SearchResultsTypeView
  @extends Ember.CollectionView
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchResultsTypeView = Ember.CollectionView.extend({
  tagName: 'ul',
  itemViewClass: Discourse.GroupedView.extend({
    tagName: 'li',
    classNameBindings: ['selected'],
    templateName: Discourse.computed.fmt('parentView.type', "search/%@_result"),
    selected: Discourse.computed.propertyEqual('content.index', 'controller.selectedIndex')
  })
});


