export default Em.Component.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  active: Discourse.computed.propertyEqual('selectedTab', 'tab'),
  title: Discourse.computed.i18n('tab', 'category.%@'),

  _addToCollection: function() {
    this.get('panels').addObject('edit-category-' + this.get('tab'));
  }.on('didInsertElement'),

  actions: {
    select: function() {
      this.set('selectedTab', this.get('tab'));
    }
  }
});
