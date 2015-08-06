export default Discourse.Route.extend({
  model() {
    if (PreloadStore.get("badges")) {
      return PreloadStore.getAndRemove("badges").then(json => Discourse.Badge.createFromJson(json));
    } else {
      return Discourse.Badge.findAll({ onlyListable: true });
    }
  },

  titleToken() {
    return I18n.t("badges.title");
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
