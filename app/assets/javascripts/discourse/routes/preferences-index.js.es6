export default Discourse.RestrictedUserRoute.extend({
  renderTemplate: function() {
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  }
});
