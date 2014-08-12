import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  categories: function() {
    return Discourse.Category.list();
  }.property(),

  navItems: function() {
    return Discourse.NavItem.buildList();
  }.property()
});
