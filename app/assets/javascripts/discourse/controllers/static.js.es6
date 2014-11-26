export default Em.ObjectController.extend({
  showLoginButton: Em.computed.equal('path', 'login'),

  actions: {
    markFaqRead: function() {
      // Anons can't get FAQ credit (where to store it in the DB?)
      if (Discourse.User.current()) {
        Discourse.ajax("/users/read-faq", { method: "POST" });
      }
    }
  }
});
