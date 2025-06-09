import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { TrackedSet } from "@ember-compat/tracked-built-ins";

class ChangeTracker {
  @tracked dirtyLightColors = new TrackedSet();
  @tracked dirtyDarkColors = new TrackedSet();

  addDirtyLightColor(name) {
    this.dirtyLightColors.add(name);
  }

  addDirtyDarkColor(name) {
    this.dirtyDarkColors.add(name);
  }

  removeDirtyLightColor(name) {
    this.dirtyLightColors.delete(name);
  }

  removeDirtyDarkColor(name) {
    this.dirtyDarkColors.delete(name);
  }

  clear() {
    this.dirtyLightColors.clear();
    this.dirtyDarkColors.clear();
  }

  get dirtyColorsCount() {
    return this.dirtyLightColors.size + this.dirtyDarkColors.size;
  }
}

export default class AdminCustomizeThemesShowColorsController extends Controller {
  colorPaletteChangeTracker = new ChangeTracker();
}
