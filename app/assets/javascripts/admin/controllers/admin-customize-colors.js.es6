import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import showModal from "discourse/lib/show-modal";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  @discourseComputed("model.@each.id")
  baseColorScheme() {
    return this.model.findBy("is_base", true);
  },

  @discourseComputed("model.@each.id")
  baseColorSchemes() {
    return this.model.filterBy("is_base", true);
  },

  @discourseComputed("baseColorScheme")
  baseColors(baseColorScheme) {
    const baseColorsHash = EmberObject.create({});
    baseColorScheme.get("colors").forEach(color => {
      baseColorsHash.set(color.get("name"), color);
    });
    return baseColorsHash;
  },

  actions: {
    newColorSchemeWithBase(baseKey) {
      const base = this.baseColorSchemes.findBy("base_scheme_id", baseKey);
      const newColorScheme = Ember.copy(base, true);
      newColorScheme.setProperties({
        name: I18n.t("admin.customize.colors.new_name"),
        base_scheme_id: base.get("base_scheme_id")
      });
      newColorScheme.save().then(() => {
        this.model.pushObject(newColorScheme);
        newColorScheme.set("savingStatus", null);
        this.replaceRoute("adminCustomize.colors.show", newColorScheme);
      });
    },

    newColorScheme() {
      showModal("admin-color-scheme-select-base", {
        model: this.baseColorSchemes,
        admin: true
      });
    }
  }
});
