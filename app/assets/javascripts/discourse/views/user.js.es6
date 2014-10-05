export default Ember.View.extend(Discourse.ScrollTop, {
  templateName: 'user/user',
  userBinding: 'controller.content',

  updateTitle: function() {
    var username = this.get('user.username');
    if (username) {
      Discourse.set('title', "" + (I18n.t("user.profile")) + " - " + username);
    }
  }.observes('user.loaded', 'user.username')
});
