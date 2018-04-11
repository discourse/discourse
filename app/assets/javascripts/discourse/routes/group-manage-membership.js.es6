export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.manage.membership.title');
  },

  afterModel(group) {
    if (group.get('automatic')) {
      this.replaceWith("group.manage.interaction", group);
    }
  },
});
