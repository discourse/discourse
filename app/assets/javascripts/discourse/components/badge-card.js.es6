import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  size: 'medium',
  classNameBindings: [':badge-card', 'size'],

  @computed('size')
  summary(size) {
    if (size === 'large') {
      return Discourse.Emoji.unescape(this.get('badge.long_description') || '');
    }
    return this.get('badge.translatedDescription');
  }

});
