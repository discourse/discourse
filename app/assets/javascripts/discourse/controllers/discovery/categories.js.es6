import computed from 'ember-addons/ember-computed-decorators';
import DiscoveryController from 'discourse/controllers/discovery';

export default DiscoveryController.extend({
  discovery: Ember.inject.controller(),

  // this makes sure the composer isn't scoping to a specific category
  category: null,

  @computed
  canEdit() {
    return Discourse.User.currentProp('staff');
  },

  @computed("model.categories.[].featuredTopics.length")
  latestTopicOnly() {
    return this.get("model.categories").find(c => c.get("featuredTopics.length") > 1) === undefined;
  },

  @computed("model.parentCategory")
  categoryPageStyle(parentCategory) {
    const style = this.siteSettings.desktop_category_page_style;
    const componentName = (parentCategory && style === "categories_and_latest_topics") ?
                          "categories_only" :
                          style;
    return Ember.String.dasherize(componentName);
  }

});
