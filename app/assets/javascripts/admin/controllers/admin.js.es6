import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  showBadges: function() {
    return this.get('currentUser.admin') && this.siteSettings.enable_badges;
  }.property()
});
