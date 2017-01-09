import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  @computed('model.@each.enabled_setting')
  adminRoutes() {
    let routes = []

    this.get('model').forEach(p => {
      if (this.siteSettings[p.get('enabled_setting')] && p.get('admin_route')) {
        routes.push(p.get('admin_route'));
      }
    });

    return routes;
  }
});
