import DiscoveryController from 'discourse/controllers/discovery';

export default DiscoveryController.extend({
  needs: ['modal', 'discovery'],

  withLogo: Em.computed.filterBy('model.categories', 'logo_url'),
  showPostsColumn: Em.computed.empty('withLogo'),

  // this makes sure the composer isn't scoping to a specific category
  category: null,

  actions: {

    refresh() {
      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      this.set('controllers.discovery.loading', true);

      const CategoryList = require('discourse/models/category-list').default;
      const parentCategory = this.get('model.parentCategory');
      const promise = parentCategory ? CategoryList.listForParent(this.store, parentCategory) :
                                       CategoryList.list(this.store);

      const self = this;
      promise.then(function(list) {
        self.set('model', list);
        self.send('loadingComplete');
      });
    }
  },

  canEdit: function() {
    return Discourse.User.currentProp('staff');
  }.property(),

  latestTopicOnly: function() {
    return this.get('model.categories').find(c => c.get('featuredTopics.length') > 1) === undefined;
  }.property('model.categories.@each.featuredTopics.length')

});
