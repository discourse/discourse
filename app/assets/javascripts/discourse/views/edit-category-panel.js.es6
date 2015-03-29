export default Em.View.extend({
  classNameBindings: [':modal-tab', 'invisible'],
  invisible: Discourse.computed.propertyNotEqual('controller.selectedTab', 'tab'),

  templateName: function() {
    return "modal/edit-category-" + this.get('tab');
  }.property('tab')
});

