import showModal from "discourse/lib/show-modal";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  @computed("model.@each.id")
  baseColorScheme() {
    return this.get("model").findBy("is_base", true);
  },

  @computed("model.@each.id")
  baseColorSchemes() {
    return this.get("model").filterBy("is_base", true);
  },

  @computed("baseColorScheme")
  baseColors(baseColorScheme) {
    const baseColorsHash = Ember.Object.create({});
    baseColorScheme.get("colors").forEach(color => {
      baseColorsHash.set(color.get("name"), color);
    });
    return baseColorsHash;
  },

  actions: {
    newColorSchemeWithBase(baseKey) {
      const base = this.get("baseColorSchemes").findBy(
        "base_scheme_id",
        baseKey
      );
      const newColorScheme = Ember.copy(base, true);
      newColorScheme.setProperties({
        name: I18n.t("admin.customize.colors.new_name"),
        base_scheme_id: base.get("base_scheme_id")
      });
      newColorScheme.save().then(() => {
        this.get("model").pushObject(newColorScheme);
        newColorScheme.set("savingStatus", null);
        this.replaceRoute("adminCustomize.colors.show", newColorScheme);
      });
    },

    newColorScheme() {
      showModal("admin-color-scheme-select-base", {
        model: this.get("baseColorSchemes"),
        admin: true
      });
    }
  }
});
