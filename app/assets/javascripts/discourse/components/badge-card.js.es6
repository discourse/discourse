import computed from 'ember-addons/ember-computed-decorators';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  size: 'medium',
  classNameBindings: [':badge-card', 'size', 'navigateOnClick:hyperlink'],

  click(e){
    if (e.target && e.target.nodeName === "A") {
      return true;
    }

    if (!this.get('navigateOnClick')) {
      return false;
    }

    var url = this.get('badge.url');
    const username = this.get('username');
    if (username) {
      url = url + "?username=" + encodeURIComponent(username);
    }
    DiscourseURL.routeTo(url);
    return true;
  },

  @computed('count', 'badge.grant_count')
  displayCount(count, grantCount) {
    if (count == null) {
      return grantCount;
    }
    if (count > 1) {
      return count;
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
