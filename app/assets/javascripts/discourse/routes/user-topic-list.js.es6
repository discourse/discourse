export default Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_topics_list');
  },

  setupController: function(controller, model) {
    this.controllerFor('user-activity').set('userActionType', this.get('userActionType'));
    this.controllerFor('user-topics-list').setProperties({
      model: model,
      hideCategory: false,
      showParticipants: false
    });
  }
});
