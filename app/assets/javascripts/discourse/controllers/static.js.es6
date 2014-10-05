export default Em.ObjectController.extend({
  showLoginButton: Em.computed.equal('path', 'login'),

  actions: {
    markFaqRead: function() {
      Discourse.ajax("/users/read-faq", { method: "POST" });
    }
  }
});
