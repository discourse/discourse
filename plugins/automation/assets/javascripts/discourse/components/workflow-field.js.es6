export default Ember.Component.extend({
  fieldName: null,
  fieldSpecification: null,
  object: null,
  workflow: null,

  init() {
    this._super(...arguments);

    let value;
    let useProvided = false;
    const option = this.object.options[this.fieldName];
    if (option) {
      value = option.value;
      useProvided = option.use_provided;
      if (Ember.isEmpty(value)) {
        if (this.fieldSpecification.default) {
          value = this.fieldSpecification.default;
        }
      }
    }

    this.set("fieldParams", Ember.Object.create({ value, useProvided }));
  },

  displayed: Ember.computed.not("fieldParams.useProvided"),

  actions: {
    onChangeValue(value) {
      this.set("fieldParams.value", value);
      this.onChange(this.fieldName, this.fieldParams);
    },

    onChangeUseProvided(event) {
      this.set("fieldParams.useProvided", event.target.checked);
      this.onChange(this.fieldName, this.fieldParams);
    }
  }
});
