export default Discourse.Route.extend({
  showFooter: true,

  model() {
    return this.store.findAll("tagGroup");
  },

  titleToken() {
    return I18n.t("tagging.groups.title");
  }
});
