import showModal from "discourse/lib/show-modal";

export default Ember.Controller.extend({
  baseColorScheme: function() {
    return this.get("model").findBy("is_base", true);
  }.property("model.@each.id"),

  baseColorSchemes: function() {
    return this.get("model").filterBy("is_base", true);
  }.property("model.@each.id"),

  baseColors: function() {
    var baseColorsHash = Ember.Object.create({});
    this.get("baseColorScheme.colors").forEach(color => {
      baseColorsHash.set(color.get("name"), color);
    });
    return baseColorsHash;
  }.property("baseColorScheme"),

  actions: {
    newColorSchemeWithBase(baseKey) {
      const base = this.get("baseColorSchemes").findBy(
        "base_scheme_id",
        baseKey
      );
      const newColorScheme = Ember.copy(base, true);
      newColorScheme.set("name", I18n.t("admin.customize.colors.new_name"));
      newColorScheme.set("base_scheme_id", base.get("base_scheme_id"));
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
