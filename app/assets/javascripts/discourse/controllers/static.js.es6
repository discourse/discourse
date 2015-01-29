export default Em.ObjectController.extend({
  showLoginButton: Em.computed.equal('path', 'login'),

  actions: {
    markFaqRead: function() {
      if (Discourse.User.current()) {
        Discourse.ajax("/users/read-faq", { method: "POST" });
      }
    }
  }
});
