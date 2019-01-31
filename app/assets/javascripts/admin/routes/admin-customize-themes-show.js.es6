import { scrollTop } from "discourse/mixins/scroll-top";
import { THEMES, COMPONENTS } from "admin/models/theme";

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

    const parentController = this.controllerFor("adminCustomizeThemes");
    parentController.setProperties({
      editingTheme: false,
      currentTab: model.get("component") ? COMPONENTS : THEMES
    });

    controller.setProperties({
      model: model,
      parentController: parentController,
      allThemes: parentController.get("model"),
      colorSchemeId: model.get("color_scheme_id"),
      colorSchemes: parentController.get("model.extras.color_schemes")
    });

    this.handleHighlight(model);
  },

  deactivate() {
    this.handleHighlight();
  },

  handleHighlight(theme) {
    this.get("controller.allThemes")
      .filter(t => t.get("selected"))
      .forEach(t => t.set("selected", false));
    if (theme) {
      theme.set("selected", true);
    }
  },

  actions: {
    didTransition() {
      scrollTop();
    }
  }
});
