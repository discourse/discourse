export default Discourse.Route.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.interaction.title");
  }
});
