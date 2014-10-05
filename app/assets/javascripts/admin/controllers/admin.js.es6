import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  showBadges: function() {
    return this.get('currentUser.admin') && Discourse.SiteSettings.enable_badges;
  }.property()
});
