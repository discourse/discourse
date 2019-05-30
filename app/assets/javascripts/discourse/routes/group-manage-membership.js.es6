export default Discourse.Route.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.membership.title");
  },

  afterModel(group) {
    if (group.automatic) {
      this.replaceWith("group.manage.interaction", group);
    }
  }
});
