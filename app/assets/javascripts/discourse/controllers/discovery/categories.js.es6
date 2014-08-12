import DiscoveryController from 'discourse/controllers/discovery';

export default DiscoveryController.extend({
  needs: ['modal', 'discovery'],

  withLogo: Em.computed.filterBy('categories', 'logo_url'),
  showPostsColumn: Em.computed.empty('withLogo'),

  actions: {
    refresh: function() {
      var self = this;

      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      this.send('loading');
      Discourse.CategoryList.list('categories').then(function(list) {
        self.set('model', list);
        self.send('loadingComplete');
      });
    }
  },

  canEdit: function() {
    return Discourse.User.currentProp('staff');
  }.property(),

  latestTopicOnly: function() {
    return this.get('categories').find(function(c) { return c.get('featuredTopics.length') > 1; }) === undefined;
  }.property('categories.@each.featuredTopics.length')

});
