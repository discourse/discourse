import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { THEMES } from "discourse/admin/models/theme";

export default class AdminCustomizeThemesController extends Controller {
  currentTab = THEMES;

  @computed("model", "model.@each.component")
  get fullThemes() {
    return this.model.filter((t) => !t.get("component"));
  }

  @computed("model", "model.@each.component")
  get childThemes() {
    return this.model.filter((t) => t.get("component"));
  }

  @computed("model.content")
  get installedThemes() {
    return this.model?.content || [];
  }
}
