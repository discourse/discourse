/**
  Represents the sort order of something, for example a topics list.

  @class SortOrder
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/
Discourse.SortOrder = Ember.Object.extend({
  order: 'default',
  descending: true,

  /**
    Changes the sort to another column

    @method toggle
    @params {String} order the new sort order
  **/
  toggle: function(order) {
    if (this.get('order') === order) {
      this.toggleProperty('descending');
    } else {
      this.setProperties({
        order: order,
        descending: true
      });
    }
  }

});
