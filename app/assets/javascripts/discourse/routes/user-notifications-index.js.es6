export default Discourse.Route.extend({
  controllerName: 'user-notifications',
  renderTemplate() {
    this.render("user/notifications-index");
  }
});
