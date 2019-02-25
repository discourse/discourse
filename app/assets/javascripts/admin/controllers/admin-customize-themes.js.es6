import { default as computed } from "ember-addons/ember-computed-decorators";
import { THEMES } from "admin/models/theme";

export default Ember.Controller.extend({
  currentTab: THEMES,

  @computed("model", "model.@each.component")
  fullThemes(themes) {
    return themes.filter(t => !t.get("component"));
  },

  @computed("model", "model.@each.component")
  childThemes(themes) {
    return themes.filter(t => t.get("component"));
  }
});
