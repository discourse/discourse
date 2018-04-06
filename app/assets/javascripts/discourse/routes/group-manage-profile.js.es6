export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.manage.profile.title');
  },

  model() {
    return this.modelFor('group');
  },
});
