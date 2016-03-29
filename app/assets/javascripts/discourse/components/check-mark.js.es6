import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'span',
  classNameBindings: [':check-display', 'status'],

  @computed('checked')
  status(checked) {
    return checked ? 'status-checked' : 'status-unchecked';
  },

  render(buffer) {
    const icon = this.get('checked') ? 'check' : 'times';
    buffer.push(`<i class='fa fa-${icon}'></i>`);
  }
});
