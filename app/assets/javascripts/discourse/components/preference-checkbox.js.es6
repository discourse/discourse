export default Em.Component.extend({
  classNames: ['controls'],

  label: function() {
    return I18n.t(this.get('labelKey'));
  }.property('labelKey'),

  click() {
    const warning = this.get('warning');

    if (warning && !this.get('checked')) {
      debugger;
      this.sendAction('warning');
      return false;
    }

    return true;
  }
});
