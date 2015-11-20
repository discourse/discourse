import AdminUser from 'admin/models/admin-user';

export default Discourse.Route.extend({
  serialize(model) {
    return { username: model.get('username').toLowerCase() };
  },

  model(params) {
    return AdminUser.find(Em.get(params, 'username').toLowerCase());
  },

  renderTemplate() {
    this.render({into: 'admin'});
  },

  afterModel(adminUser) {
    return adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      return adminUser;
    });
  }
});
