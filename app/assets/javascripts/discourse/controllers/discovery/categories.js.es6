import computed from 'ember-addons/ember-computed-decorators';
import DiscoveryController from 'discourse/controllers/discovery';

export default DiscoveryController.extend({
  needs: ['modal', 'discovery'],

  withLogo: Em.computed.filterBy('model.categories', 'logo_url'),
  showPostsColumn: Em.computed.empty('withLogo'),

  // this makes sure the composer isn't scoping to a specific category
  category: null,

  @computed
  canEdit() {
    return Discourse.User.currentProp('staff');
  },

  @computed("model.categories.@each.featuredTopics.length")
  latestTopicOnly() {
    return this.get("model.categories").find(c => c.get('featuredTopics.length') > 1) === undefined;
  }

});
