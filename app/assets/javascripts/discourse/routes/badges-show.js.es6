export default Discourse.Route.extend({
  actions: {
    didTransition() {
      this.controllerFor("badges/show")._showFooter();
      return true;
    }
  },

  serialize(model) {
    return {
      id: model.get("id"),
      slug: model.get("name").replace(/[^A-Za-z0-9_]+/g, "-").toLowerCase()
    };
  },

  model(params) {
    if (PreloadStore.get("badge")) {
      return PreloadStore.getAndRemove("badge").then(json => Discourse.Badge.createFromJson(json));
    } else {
      return Discourse.Badge.findById(params.id);
    }
  },

  afterModel(model) {
    return Discourse.UserBadge.findByBadgeId(model.get("id")).then(userBadges => {
      this.userBadges = userBadges;
    });
  },

  titleToken() {
    const model = this.modelFor("badges.show");
    if (model) {
      return model.get("displayName");
    }
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("userBadges", this.userBadges);
  }
});
