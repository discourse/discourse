import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowColorsController extends Controller {
  @tracked pendingChangesCount = 0;

  pendingLightColors = new Set();
  pendingDarkColors = new Set();

  get pendingChangesBannerLabel() {
    return i18n("admin.customize.theme.unsaved_colors", {
      count: this.pendingChangesCount,
    });
  }

  get pendingChangesSaveLabel() {
    return i18n("admin.customize.theme.save_colors");
  }

  get pendingChangesDiscardLabel() {
    return i18n("admin.customize.theme.discard_colors");
  }

  @action
  onLightColorChange(name, value) {
    const color = this.model.colorPalette.colors.find((c) => c.name === name);
    color.hex = value;
    if (color.hex !== color.originalHex) {
      this.pendingLightColors.add(name);
    } else {
      this.pendingLightColors.delete(name);
    }
    this.pendingChangesCount =
      this.pendingLightColors.size + this.pendingDarkColors.size;
  }

  @action
  onDarkColorChange(name, value) {
    const color = this.model.colorPalette.colors.find((c) => c.name === name);
    color.dark_hex = value;
    if (color.dark_hex !== color.originalDarkHex) {
      this.pendingDarkColors.add(name);
    } else {
      this.pendingDarkColors.delete(name);
    }
    this.pendingChangesCount =
      this.pendingLightColors.size + this.pendingDarkColors.size;
  }

  @action
  async save() {
    await this.model.changeColors();
    this.pendingLightColors.clear();
    this.pendingDarkColors.clear();
    this.pendingChangesCount = 0;
  }

  @action
  discard() {
    this.model.discardColorChanges();
    this.pendingLightColors.clear();
    this.pendingDarkColors.clear();
    this.pendingChangesCount = 0;
  }
}
