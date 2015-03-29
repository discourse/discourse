import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username_lower'), {grouped: true});
  },

  setupController: function(controller, model) {
    if (this.controllerFor('user_activity').get('content')) {
      this.controllerFor('user_activity').set('userActionType', -1);
    }
    controller.set('model', model);
  },

  renderTemplate: function() {
    this.render('user/badges', {into: 'user'});
  }
});
