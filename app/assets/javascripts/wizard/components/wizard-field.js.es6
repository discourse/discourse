import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':wizard-field', ':text-field', 'field.invalid'],

  @computed('field.id')
  inputClassName: id => `field-${Ember.String.dasherize(id)}`,

  @computed('field.type', 'field.id')
  inputComponentName(type, id) {
    return (type === 'component') ? Ember.String.dasherize(id) : `wizard-field-${type}`;
  }

});
