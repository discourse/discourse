export default Em.Component.extend({
  classNames: ['controls'],

  label: function() {
    return I18n.t(this.get('labelKey'));
  }.property('labelKey')
});
