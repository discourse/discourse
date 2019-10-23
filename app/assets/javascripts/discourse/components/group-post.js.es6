import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("post.url")
  postUrl: Discourse.getURL
});
