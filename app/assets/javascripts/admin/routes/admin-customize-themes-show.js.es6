import { scrollTop } from "discourse/mixins/scroll-top";

export default Ember.Route.extend({
  serialize(model) {
    return { theme_id: model.get("id") };
  },

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id));
    return model ? model : this.replaceWith("adminCustomizeTheme.index");
  },

  setupController(controller, model) {
    this._super(...arguments);

    controller.set("model", model);

    const parentController = this.controllerFor("adminCustomizeThemes");
    parentController.set("editingTheme", false);
    controller.set("allThemes", parentController.get("model"));

    this.handleHighlight(model);

    controller.set(
      "colorSchemes",
      parentController.get("model.extras.color_schemes")
    );
    controller.set("colorSchemeId", model.get("color_scheme_id"));
  },

  deactivate() {
    this.handleHighlight();
  },

  handleHighlight(theme) {
    this.get("controller.allThemes").forEach(t => t.set("active", false));
    if (theme) {
      theme.set("active", true);
    }
  },

  actions: {
    didTransition() {
      scrollTop();
    }
  }
});
