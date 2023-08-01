import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";

export default class AdminCustomizeColorsController extends Controller {
  @service router;

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
      name: I18n.t("admin.customize.colors.new_name"),
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
    showModal("admin-color-scheme-select-base", {
      model: this.baseColorSchemes,
      admin: true,
    });
  }
}
