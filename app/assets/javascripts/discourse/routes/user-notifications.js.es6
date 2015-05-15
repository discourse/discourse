import ShowFooter from "discourse/mixins/show-footer";
import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ShowFooter, ViewingActionType, {
  actions: {
    didTransition() {
      this.controllerFor("user-notifications")._showFooter();
      return true;
    }
  },

  model() {
    var user = this.modelFor('user');
    return this.store.find('notification', {username: user.get('username')});
  },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('user', this.modelFor('user'));
    this.viewingActionType(-1);
  }
});
