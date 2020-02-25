import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { THEMES } from "admin/models/theme";

export default Controller.extend({
  currentTab: THEMES,

  @discourseComputed("model", "model.@each.component")
  fullThemes(themes) {
    return themes.filter(t => !t.get("component"));
  },

  @discourseComputed("model", "model.@each.component")
  childThemes(themes) {
    return themes.filter(t => t.get("component"));
  },

  @discourseComputed("model", "model.@each.component")
  installedThemes(themes) {
    return themes.map(t => t.name);
  }
});
