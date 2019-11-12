import discourseComputed from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import ColorSchemeColor from "admin/models/color-scheme-color";
import EmberObject from "@ember/object";

const ColorScheme = EmberObject.extend(Ember.Copyable, {
  init() {
    this._super(...arguments);

    this.startTrackingChanges();
  },

  @discourseComputed
  description() {
    return "" + this.name;
  },

  startTrackingChanges() {
    this.set("originals", { name: this.name });
  },

  schemeJson() {
    const buffer = [];
    this.colors.forEach(c => {
      buffer.push(`  "${c.get("name")}": "${c.get("hex")}"`);
    });

    return [`"${this.name}": {`, buffer.join(",\n"), "}"].join("\n");
  },

  copy() {
    const newScheme = ColorScheme.create({
      name: this.name,
      can_edit: true,
      colors: Ember.A()
    });
    this.colors.forEach(c => {
      newScheme.colors.pushObject(
        ColorSchemeColor.create(c.getProperties("name", "hex", "default_hex"))
      );
    });
    return newScheme;
  },

  @discourseComputed("name", "colors.@each.changed", "saving")
  changed(name) {
    if (!this.originals) return false;
    if (this.originals.name !== name) return true;
    if (this.colors.any(c => c.get("changed"))) return true;

    return false;
  },

  @discourseComputed("changed")
  disableSave(changed) {
    if (this.theme_id) {
      return false;
    }

    return !changed || this.saving || this.colors.any(c => !c.get("valid"));
  },

  newRecord: not("id"),

  save(opts) {
    if (this.is_base || this.disableSave) return;

    this.setProperties({ savingStatus: I18n.t("saving"), saving: true });

    const data = {};

    if (!opts || !opts.enabledOnly) {
      data.name = this.name;
      data.base_scheme_id = this.base_scheme_id;
      data.colors = [];
      this.colors.forEach(c => {
        if (!this.id || c.get("changed")) {
          data.colors.pushObject(c.getProperties("name", "hex"));
        }
      });
    }

    return ajax(
      "/admin/color_schemes" + (this.id ? "/" + this.id : "") + ".json",
      {
        data: JSON.stringify({ color_scheme: data }),
        type: this.id ? "PUT" : "POST",
        dataType: "json",
        contentType: "application/json"
      }
    ).then(result => {
      if (result.id) {
        this.set("id", result.id);
      }

      if (!opts || !opts.enabledOnly) {
        this.startTrackingChanges();
        this.colors.forEach(c => c.startTrackingChanges());
      }

      this.setProperties({ savingStatus: I18n.t("saved"), saving: false });
      this.notifyPropertyChange("description");
    });
  },

  destroy() {
    if (this.id) {
      return ajax(`/admin/color_schemes/${this.id}`, { type: "DELETE" });
    }
  }
});

const ColorSchemes = Ember.ArrayProxy.extend({});

ColorScheme.reopenClass({
  findAll() {
    const colorSchemes = ColorSchemes.create({ content: [], loading: true });
    return ajax("/admin/color_schemes").then(all => {
      all.forEach(colorScheme => {
        colorSchemes.pushObject(
          ColorScheme.create({
            id: colorScheme.id,
            name: colorScheme.name,
            is_base: colorScheme.is_base,
            theme_id: colorScheme.theme_id,
            theme_name: colorScheme.theme_name,
            base_scheme_id: colorScheme.base_scheme_id,
            colors: colorScheme.colors.map(c => {
              return ColorSchemeColor.create({
                name: c.name,
                hex: c.hex,
                default_hex: c.default_hex,
                is_advanced: c.is_advanced
              });
            })
          })
        );
      });
      return colorSchemes;
    });
  }
});

export default ColorScheme;
