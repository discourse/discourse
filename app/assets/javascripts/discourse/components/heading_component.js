Discourse.DiscourseHeadingComponent = Ember.Component.extend({
  tagName: 'th',

  classNameBindings: ['number:num', 'sortBy', 'iconSortClass:sorting', 'sortable'],
  attributeBindings: ['colspan'],

  sortable: function() {
    return this.get('sortOrder') && this.get('sortBy');
  }.property('sortOrder', 'sortBy'),

  iconSortClass: function() {
    var sortable = this.get('sortable');

    if (sortable && this.get('sortBy') === this.get('sortOrder.order')) {
      return this.get('sortOrder.descending') ? 'icon-chevron-down' : 'icon-chevron-up';
    }
  }.property('sortable', 'sortOrder.order', 'sortOrder.descending'),

  click: function() {
    var sortOrder = this.get('sortOrder'),
        sortBy = this.get('sortBy');

    if (sortBy && sortOrder) {
      sortOrder.toggle(sortBy);
    }
  }
});
