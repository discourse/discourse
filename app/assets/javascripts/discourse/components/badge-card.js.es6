import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  size: 'medium',
  classNameBindings: [':badge-card', 'size'],

  @computed('count', 'badge.grant_count')
  displayCount(count, grantCount) {
    const count = parseInt(count || grantCount || 0);
    if (count > 1) {
      return count;
    }
  },

  @computed('size')
  summary(size) {
    if (size === 'large') {
      return Discourse.Emoji.unescape(this.get('badge.long_description') || '');
    }
    return this.get('badge.translatedDescription');
  }

});
