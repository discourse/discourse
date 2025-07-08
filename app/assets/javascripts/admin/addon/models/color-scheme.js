import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import ArrayProxy from "@ember/array/proxy";
import EmberObject from "@ember/object";
import { not } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ColorSchemeColor from "admin/models/color-scheme-color";

class ColorSchemes extends ArrayProxy {}

export default class ColorScheme extends EmberObject {
  static findAll({ excludeThemeOwned = false } = {}) {
    const colorSchemes = ColorSchemes.create({ content: [], loading: true });

    const data = {};
    if (excludeThemeOwned) {
      data.exclude_theme_owned = true;
    }

    return ajax("/admin/color_schemes", { data }).then((all) => {
      all.forEach((colorScheme) => {
        colorSchemes.pushObject(
          ColorScheme.create({
            id: colorScheme.id,
            name: colorScheme.name,
            is_base: colorScheme.is_base,
            theme_id: colorScheme.theme_id,
            theme_name: colorScheme.theme_name,
            base_scheme_id: colorScheme.base_scheme_id,
            user_selectable: colorScheme.user_selectable,
            colors: colorScheme.colors,
          })
        );
      });
      return colorSchemes;
    });
  }

  static async find(id) {
    const json = await ajax(`/admin/config/colors/${id}`);
    return ColorScheme.create({
      id: json.id,
      name: json.name,
      is_base: json.is_base,
      theme_id: json.theme_id,
      theme_name: json.theme_name,
      base_scheme_id: json.base_scheme_id,
      user_selectable: json.user_selectable,
      colors: json.colors,
    });
  }

  @tracked name;
  @tracked user_selectable;

  @not("id") newRecord;

  init() {
    super.init(...arguments);

    const colors = A(this.colors ?? []);
    this.colors = colors.map((c) => {
      return ColorSchemeColor.create(c);
    });
    this.startTrackingChanges();
  }

  @discourseComputed
  description() {
    return "" + this.name;
  }

  startTrackingChanges() {
    this.set("originals", {
      name: this.name,
      user_selectable: this.user_selectable,
    });
  }

  schemeJson() {
    const buffer = [];
    this.colors.forEach((c) => {
      buffer.push(`  "${c.get("name")}": "${c.get("hex")}"`);
    });

    return [`"${this.name}": {`, buffer.join(",\n"), "}"].join("\n");
  }

  schemeObject() {
    const extractColors = (property) =>
      Object.fromEntries(
        this.colors.map((color) => [color.name, color[property]])
      );
    return {
      name: this.name,
      dark: extractColors("dark_hex"),
      light: extractColors("hex"),
    };
  }

  /**
   * @returns a JSON representation of the color scheme.
   */
  dump() {
    return JSON.stringify(this.schemeObject(), null, 2);
  }

  copy() {
    const newScheme = ColorScheme.create({
      name: this.name,
      can_edit: true,
      colors: A(),
    });
    this.colors.forEach((c) => {
      newScheme.colors.pushObject(
        ColorSchemeColor.create(
          c.getProperties("name", "hex", "default_hex", "dark_hex")
        )
      );
    });
    return newScheme;
  }

  @discourseComputed(
    "name",
    "user_selectable",
    "colors.@each.changed",
    "saving"
  )
  changed(name, user_selectable) {
    if (!this.originals) {
      return false;
    }
    if (this.originals.name !== name) {
      return true;
    }
    if (this.originals.user_selectable !== user_selectable) {
      return true;
    }
    if (this.colors.any((c) => c.get("changed"))) {
      return true;
    }

    return false;
  }

  @discourseComputed("changed")
  disableSave(changed) {
    if (this.theme_id) {
      return false;
    }

    return !changed || this.saving || this.colors.any((c) => !c.get("valid"));
  }

  save(opts) {
    if (!opts?.forceSave && (this.is_base || this.disableSave)) {
      return;
    }

    this.setProperties({ savingStatus: i18n("saving"), saving: true });

    const data = {};
    if (!opts || !opts.enabledOnly) {
      data.name = this.name;

      if (!opts?.saveNameOnly) {
        data.user_selectable = this.user_selectable;
        data.base_scheme_id = this.base_scheme_id;
        data.colors = [];
        this.colors.forEach((c) => {
          if (!this.id || c.get("changed")) {
            data.colors.pushObject(c.getProperties("name", "hex", "dark_hex"));
          }
        });
      }
    }

    return ajax(`/admin/color_schemes${this.id ? `/${this.id}` : ""}.json`, {
      data: JSON.stringify({ color_scheme: data }),
      type: this.id ? "PUT" : "POST",
      dataType: "json",
      contentType: "application/json",
    }).then((result) => {
      if (result.id) {
        this.set("id", result.id);
      }

      if (!opts?.saveNameOnly) {
        if (!opts || !opts.enabledOnly) {
          this.startTrackingChanges();
          this.colors.forEach((c) => c.startTrackingChanges());
        }
      }

      this.setProperties({ savingStatus: i18n("saved"), saving: false });
      this.notifyPropertyChange("description");
    });
  }

  updateUserSelectable(value) {
    if (!this.id) {
      return;
    }

    return ajax(`/admin/color_schemes/${this.id}.json`, {
      data: JSON.stringify({ color_scheme: { user_selectable: value } }),
      type: "PUT",
      dataType: "json",
      contentType: "application/json",
    });
  }

  destroy() {
    if (this.id) {
      return ajax(`/admin/color_schemes/${this.id}`, { type: "DELETE" });
    }
  }
}
