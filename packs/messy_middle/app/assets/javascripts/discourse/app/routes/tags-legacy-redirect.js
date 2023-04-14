import Route from "@ember/routing/route";

export default Route.extend({
  beforeModel() {
    this.transitionTo("tag.show", this.paramsFor("tags.legacyRedirect").tag_id);
  },
});
