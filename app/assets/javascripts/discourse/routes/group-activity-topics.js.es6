import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t(`groups.topics`);
  },

  model() {
    return this.store.findFiltered("topicList", {
      filter: `topics/groups/${this.modelFor("group").get("name")}`
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
