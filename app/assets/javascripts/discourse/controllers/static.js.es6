export default Ember.Controller.extend({
  showLoginButton: Em.computed.equal("model.path", "login"),

  actions: {
    markFaqRead() {
      if (this.currentUser) {
        Discourse.ajax("/users/read-faq", { method: "POST" });
      }
    }
  }
});
