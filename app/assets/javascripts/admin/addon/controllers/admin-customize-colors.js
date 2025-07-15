import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";

export default class AdminCustomizeColorsController extends Controller {
  @service router;
  @service modal;
  @service store;
  @service dialog;

  @tracked defaultTheme = null;

  isDefaultThemeColorScheme = (scheme) => {
    return this.defaultTheme?.color_scheme_id === scheme.id;
  };

  @discourseComputed("model.@each.id")
  baseColorScheme() {
    return this.model.findBy("is_base", true);
  }

  @discourseComputed("model.@each.id")
  baseColorSchemes() {
    return this.model.filterBy("is_base", true);
  }

  @discourseComputed("baseColorScheme")
  baseColors(baseColorScheme) {
    const baseColorsHash = EmberObject.create({});
    baseColorScheme.get("colors").forEach((color) => {
      baseColorsHash.set(color.get("name"), color);
    });
    return baseColorsHash;
  }

  @action
  newColorSchemeWithBase(baseKey) {
    const base = this.baseColorSchemes.findBy("base_scheme_id", baseKey);
    const newColorScheme = base.copy();
    newColorScheme.setProperties({
      name: i18n("admin.customize.colors.new_name"),
      base_scheme_id: base.get("base_scheme_id"),
    });
    newColorScheme.save().then(() => {
      this.model.pushObject(newColorScheme);
      newColorScheme.set("savingStatus", null);
      this.router.replaceWith("adminCustomize.colors-show", newColorScheme);
    });
  }

  @action
  newColorScheme() {
    this.modal.show(ColorSchemeSelectBaseModal, {
      model: {
        baseColorSchemes: this.baseColorSchemes,
        newColorSchemeWithBase: this.newColorSchemeWithBase,
      },
    });
  }

  @action
  toggleUserSelectable(scheme) {
    scheme.set("user_selectable", !scheme.get("user_selectable"));
    scheme.updateUserSelectable(scheme.get("user_selectable"));
  }

  @action
  setAsDefaultThemePalette(scheme) {
    this.store.findAll("theme").then((themes) => {
      const defaultTheme = themes.findBy("default", true);
      if (defaultTheme) {
        // null is the pre-seeded scheme
        const schemeId = scheme ? scheme.get("id") : null;
        defaultTheme.set("color_scheme_id", schemeId);

        this.set("defaultTheme", defaultTheme);

        defaultTheme.saveChanges("color_scheme_id").then(() => {
          // refresh to show changes
          window.location.reload();
        });
      }
    });
  }

  @action
  deleteColorScheme(scheme) {
    return this.dialog.deleteConfirm({
      title: i18n("admin.customize.colors.delete_confirm"),
      didConfirm: () => {
        return scheme.destroy().then(() => {
          this.model.removeObject(scheme);
        });
      },
    });
  }
}
