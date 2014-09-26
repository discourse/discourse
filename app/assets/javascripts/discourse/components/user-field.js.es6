export default Ember.Component.extend({
  classNameBindings: [':user-field'],
  layoutName: function() {
    return "components/user-fields/" + this.get('field.field_type');
  }.property('field.field_type')
});
