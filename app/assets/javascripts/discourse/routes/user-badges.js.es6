import ShowFooter from "discourse/mixins/show-footer";
import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ShowFooter, ViewingActionType, {
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username_lower'), {grouped: true});
  },

  setupController: function(controller, model) {
    this.viewingActionType(-1);
    controller.set('model', model);
  },

  renderTemplate: function() {
    this.render('user/badges', {into: 'user'});
  }
});
