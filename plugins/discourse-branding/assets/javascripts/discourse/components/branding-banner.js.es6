import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'div',
  classNameBindings: [':b-banner', 'style'],

  @computed('style')
  default(style) {
    if (style === 'default') {
      return true;
    }
    return false;
  },

  @computed('style')
  smart(style) {
    if (style === 'smart') {
      return true;
    }
    return false;
  },

  @computed('style')
  plugin(style) {
    if (style === 'plugin') {
      return true;
    }
    return false;
  },

});