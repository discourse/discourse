import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'i',
  classNameBindings: [':fa', 'iconClass'],

  @computed('checked')
  iconClass(checked) {
    return checked ? 'fa-check' : 'fa-times';
  }
});
