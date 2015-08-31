import Badge from 'discourse/models/badge';

export default Discourse.Route.extend({
  model() {
    if (PreloadStore.get("badges")) {
      return PreloadStore.getAndRemove("badges").then(json => Badge.createFromJson(json));
    } else {
      return Badge.findAll({ onlyListable: true });
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
