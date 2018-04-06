export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.manage.members.title');
  },

  model() {
    return this.modelFor('group');
  },
});
