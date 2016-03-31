import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({

  needs: ['application'],

  showLoginButton: Em.computed.equal("model.path", "login"),

  @computed("model.path")
  showSignupButton() {
    return this.get("model.path") === "login" && this.get('controllers.application.canSignUp');
  },

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
