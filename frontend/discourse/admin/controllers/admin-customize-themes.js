import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { THEMES } from "discourse/admin/models/theme";

export default class AdminCustomizeThemesController extends Controller {
  currentTab = THEMES;

  @computed("model.content")
  get installedThemes() {
    return this.model?.content || [];
  }
}
