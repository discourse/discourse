import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['embed-setting'],

  @computed('field')
  inputId(field) { return field.dasherize(); },

  @computed('placeholder')
  placeholderValue(placeholder) {
    return placeholder ? I18n.t(placeholder) : null;
  },

  @computed('field')
  translationKey(field) { return `admin.embedding.${field}`; },

  @computed('type')
  isCheckbox(type) { return type === "checkbox"; },

  @computed('value')
  checked: {
    get(value) { return !!value; },
    set(value) {
      this.set('value', value); 
      return value;
    }
  }
});
