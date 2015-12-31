import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ViewingActionType, {

  renderTemplate() {
    this.render('user/notifications');
  },

  actions: {
    didTransition() {
      this.controllerFor("user-notifications")._showFooter();
      return true;
    }
  },

  model() {
    const username = this.modelFor("user").get("username");

    if (this.get("currentUser.username") ===  username || this.get("currentUser.admin")) {
      return this.store.find("notification", { username } );
    }
  },


  setupController(controller, model) {
    controller.set("model", model);
    controller.set("user", this.modelFor("user"));
    this.viewingActionType(-1);
  }
});
