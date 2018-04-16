export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.manage.profile.title');
  },

  afterModel(group) {
    if (group.get('automatic')) {
      this.replaceWith("group.manage.interaction", group);
    }
  },
});
