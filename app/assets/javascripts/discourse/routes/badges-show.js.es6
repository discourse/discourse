import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  actions: {
    didTransition: function() {
      this.controllerFor("badges/show")._showFooter();
      return true;
    }
  },

  serialize: function(model) {
    return {id: model.get('id'), slug: model.get('name').replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase()};
  },

  model: function(params) {
    if (PreloadStore.get('badge')) {
      return PreloadStore.getAndRemove('badge').then(function(json) {
        return Discourse.Badge.createFromJson(json);
      });
    } else {
      return Discourse.Badge.findById(params.id);
    }
  },

  afterModel: function(model) {
    var self = this;
    return Discourse.UserBadge.findByBadgeId(model.get('id')).then(function(userBadges) {
      self.userBadges = userBadges;
    });
  },

  titleToken: function() {
    var model = this.modelFor('badges.show');
    if (model) {
      return model.get('displayName');
    }
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('userBadges', this.userBadges);
  }
});
