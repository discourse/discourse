import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  needs: ['discovery', 'discovery/topics'],

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  navItems: function() {
    return Discourse.NavItem.buildList(null, {filterMode: this.get('filterMode')});
  }.property('filterMode'),

  isSearch: Em.computed.equal('filterMode', 'search'),

  searchTerm: Em.computed.alias('controllers.discovery/topics.model.params.q'),

  actions: {
    search: function(){
      var discovery = this.get('controllers.discovery/topics');
      var model = discovery.get('model');
      discovery.set('q', this.get('searchTerm'));
      model.refreshSort();
    }
  }
});
