export default Em.Component.extend({
  tagName: 'li',
  classNameBindings: ['active', 'tabClassName'],

  tabClassName: function() {
    return 'edit-category-' + this.get('tab');
  }.property('tab'),

  active: Discourse.computed.propertyEqual('selectedTab', 'tab'),

  title: function() {
    return I18n.t('category.' + this.get('tab').replace('-', '_'));
  }.property('tab'),

  _addToCollection: function() {
    this.get('panels').addObject(this.get('tabClassName'));
  }.on('didInsertElement'),

  actions: {
    select: function() {
      this.set('selectedTab', this.get('tab'));
    }
  }
});
