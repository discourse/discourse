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
      return Discourse.Emoji.unescape(this.get('badge.long_description') || '');
    }
    return this.get('badge.displayDescriptionHtml');
  }

});
