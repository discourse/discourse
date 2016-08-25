import ValidState from 'wizard/mixins/valid-state';

export default Ember.Object.extend(ValidState, {
  id: null,
  type: null,
  value: null,
  required: null,

  check() {
    if (!this.get('required')) {
      return this.setValid(true);
    }

    const val = this.get('value');
    this.setValid(val && val.length > 0);
  }
});
