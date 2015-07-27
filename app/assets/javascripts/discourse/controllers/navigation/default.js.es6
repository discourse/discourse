import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  needs: ['discovery', 'discovery/topics'],

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  navItems: function() {
    return Discourse.NavItem.buildList(null, {filterMode: this.get('filterMode')});
  }.property('filterMode')

});
