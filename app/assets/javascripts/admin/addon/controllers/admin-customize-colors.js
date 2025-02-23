import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";

export default class AdminCustomizeColorsController extends Controller {
  @service router;
  @service modal;

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
      this.router.replaceWith("adminCustomize.colors.show", newColorScheme);
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
}
