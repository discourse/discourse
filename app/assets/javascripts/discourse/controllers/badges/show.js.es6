import UserBadge from 'discourse/models/user-badge';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  queryParams: ['username'],
  noMoreBadges: false,
  userBadges: null,
  needs: ["application"],

  user: function() {
    if (this.get("username")) {
      return this.get('userBadges')[0].get('user');
    }
  }.property("username"),

  grantCount: function() {
    if (this.get("username")) {
      return this.get('userBadges.grant_count');
    } else {
      return this.get('model.grant_count');
    }
  }.property('username', 'model', 'userBadges'),

  actions: {
    loadMore() {
      const userBadges = this.get('userBadges');

      UserBadge.findByBadgeId(this.get('model.id'), {
        offset: userBadges.length,
        username: this.get('username'),
      }).then(result => {
        userBadges.pushObjects(result);
        if (userBadges.length === 0){
          this.set('noMoreBadges', true);
        }
      });
    }
  },

  @computed('noMoreBadges', 'model.grant_count', 'userBadges.length')
  canLoadMore(noMoreBadges, grantCount, userBadgeLength) {
    if (noMoreBadges) { return false; }
    return grantCount > (userBadgeLength || 0);
  },

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }.observes("canLoadMore"),

  longDescription: function(){
    return Discourse.Emoji.unescape(this.get('model.long_description'));
  }.property('model.long_description'),

  showLongDescription: function(){
    return this.get('model.long_description');
  }.property('userBadges')

});
