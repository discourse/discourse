/**
  Renders a heading for a table with optional sorting controls.

  @class SortableHeadingComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.SortableHeadingComponent = Ember.Component.extend({
  tagName: 'th',
  classNameBindings: ['number:num', 'sortBy', 'iconSortClass:sorting', 'sortable:sortable'],
  attributeBindings: ['colspan'],

  sortable: function() {
    return this.get('order') && this.get('sortBy');
  }.property('order', 'sortBy'),

  iconSortClass: function() {
    if (this.get('sortable') && this.get('sortBy') === this.get('order')) {
      return this.get('ascending') ? 'fa fa-chevron-up' : 'fa fa-chevron-down';
    }
  }.property('sortable', 'order', 'ascending'),

  click: function() {
    this.sendAction('action', this.get('sortBy'));
  }
});
