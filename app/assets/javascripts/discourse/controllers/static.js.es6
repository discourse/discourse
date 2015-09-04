export default Ember.Controller.extend({
  showLoginButton: Em.computed.equal("model.path", "login"),

  actions: {
    markFaqRead() {
      const currentUser = this.currentUser;
      if (currentUser) {
        Discourse.ajax("/users/read-faq", { method: "POST" }).then(() => {
          currentUser.set('read_faq', true);
        });
      }
    }
  }
});
