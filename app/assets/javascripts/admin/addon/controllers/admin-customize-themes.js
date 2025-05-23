import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";
import { THEMES } from "admin/models/theme";

export default class AdminCustomizeThemesController extends Controller {
  currentTab = THEMES;

  @discourseComputed("model", "model.@each.component")
  fullThemes(themes) {
    return themes.filter((t) => !t.get("component"));
  }

  @discourseComputed("model", "model.@each.component")
  childThemes(themes) {
    return themes.filter((t) => t.get("component"));
  }

  @discourseComputed("model.content")
  installedThemes(content) {
    return content || [];
  }
}
