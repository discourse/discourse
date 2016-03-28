import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  size: 'medium',
  classNameBindings: [':badge-card', 'size'],

  @computed('count', 'badge.grant_count')
  displayCount(count, grantCount) {
    const c = parseInt(count || grantCount || 0);
    if (c > 1) {
      return c;
    }
  },

  @computed('size')
  summary(size) {
    if (size === 'large') {
      const longDescription = this.get('badge.long_description');
      if (!_.isEmpty(longDescription)) {
        return Discourse.Emoji.unescape(longDescription);
      }
    }
    return this.get('badge.description');
  }

});
