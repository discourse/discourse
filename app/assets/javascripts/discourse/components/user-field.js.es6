export default Ember.Component.extend({
  classNameBindings: [':user-field', 'field.field_type'],
  layoutName: function() {
    return "components/user-fields/" + this.get('field.field_type');
  }.property('field.field_type')
});
