import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':wizard-field', ':text-field', 'field.invalid'],

  @computed('field.id')
  inputClassName: id => `field-${Ember.String.dasherize(id)}`
});
