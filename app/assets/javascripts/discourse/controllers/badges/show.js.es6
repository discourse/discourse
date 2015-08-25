import UserBadge from 'discourse/models/user-badge';

export default Ember.Controller.extend({
  noMoreBadges: false,
  userBadges: null,
  needs: ["application"],

  actions: {
    loadMore() {
      const self = this;
      const userBadges = this.get('userBadges');

      UserBadge.findByBadgeId(this.get('model.id'), {
        offset: userBadges.length
      }).then(function(result) {
        userBadges.pushObjects(result);
        if(userBadges.length === 0){
          self.set('noMoreBadges', true);
        }
      });
    }
  },

  layoutClass: function(){
    var ub = this.get("userBadges");
    if(ub && ub[0] && ub[0].post_id){
      return "user-badge-with-posts";
    } else {
      return "user-badge-no-posts";
    }
  }.property("userBadges"),

  canLoadMore: function() {
    if (this.get('noMoreBadges')) { return false; }

    if (this.get('userBadges')) {
      return this.get('model.grant_count') > this.get('userBadges.length');
    } else {
      return false;
    }
  }.property('noMoreBadges', 'model.grant_count', 'userBadges.length'),

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"));
  }.observes("canLoadMore"),

  showLongDescription: function(){
    return window.location.search.match("long-description");
  }.property('userBadges')

});
