export default Discourse.Route.extend({
  titleToken() {
    return I18n.t(`groups.topics`);
  },

  model() {
    return this.store.findFiltered("topicList", {
      filter: `topics/groups/${this.modelFor("group").get("name")}`
    });
  }
});
