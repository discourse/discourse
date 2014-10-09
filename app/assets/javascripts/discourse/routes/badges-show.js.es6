export default Discourse.Route.extend({
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

  titleToken: function() {
    var model = this.modelFor('badges.show');
    if (model) {
      return model.get('displayName');
    }
  },

  setupController: function(controller, model) {
    Discourse.UserBadge.findByBadgeId(model.get('id')).then(function(userBadges) {
      controller.set('userBadges', userBadges);
      controller.set('userBadgesLoaded', true);
    });
    controller.set('model', model);
  }
});
