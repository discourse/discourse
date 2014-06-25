export default Em.Component.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  active: Discourse.computed.propertyEqual('selectedTab', 'tab'),
  title: Discourse.computed.i18n('tab', 'category.%@'),

  actions: {
    select: function() {
      this.set('selectedTab', this.get('tab'));
    }
  }
});
