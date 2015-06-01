import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ViewingActionType, {
  renderTemplate() {
    this.render('user-topics-list');
  },

  setupController(controller, model) {
    const userActionType = this.get('userActionType');
    this.controllerFor('user').set('userActionType', userActionType);
    this.controllerFor('user-activity').set('userActionType', userActionType);
    this.controllerFor('user-topics-list').setProperties({
      model,
      hideCategory: false,
      showParticipants: false
    });
  }
});
