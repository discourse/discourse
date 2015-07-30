export default Ember.Component.extend({
  classNameBindings: [':user-field', 'field.field_type'],
  layoutName: Discourse.computed.fmt('field.field_type', 'components/user-fields/%@'),

  noneLabel: function() {
    if (!this.get('field.required')) {
      return 'user_fields.none';
    }
  }.property('field.required')
});
