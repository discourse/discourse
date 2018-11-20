import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("post.url")
  postUrl: Discourse.getURL
});
