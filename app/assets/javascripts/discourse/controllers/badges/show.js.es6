import UserBadge from 'discourse/models/user-badge';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  queryParams: ['username'],
  noMoreBadges: false,
  userBadges: null,
  needs: ["application"],

  @computed('username')
  user(username) {
    if (username) {
      return this.get('userBadges')[0].get('user');
    }
  },

  @computed('username', 'model.grant_count', 'userBadges.grant_count')
  grantCount(username, modelCount, userCount) {
    return username ? userCount : modelCount;
  },

  actions: {
    loadMore() {
      if (this.get('loadingMore')) {
        return;
      }
      this.set('loadingMore', true);

      const userBadges = this.get('userBadges');

      UserBadge.findByBadgeId(this.get('model.id'), {
        offset: userBadges.length,
        username: this.get('username'),
      }).then(result => {
        userBadges.pushObjects(result);
        if (userBadges.length === 0){
          this.set('noMoreBadges', true);
        }
      }).finally(()=>{
        this.set('loadingMore', false);
      });
    }
  },

  @computed('noMoreBadges', 'grantCount', 'userBadges.length')
  canLoadMore(noMoreBadges, grantCount, userBadgeLength) {
    if (noMoreBadges) { return false; }
    return grantCount > (userBadgeLength || 0);
  },

  @computed('user', 'model.grant_count')
  canShowOthers(user, grantCount) {
    return !!user && grantCount > 1;
  },

  @observes('canLoadMore')
  _showFooter() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }

});
