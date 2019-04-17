import { ajax } from "discourse/lib/ajax";
import ColorSchemeColor from "admin/models/color-scheme-color";
import computed from "ember-addons/ember-computed-decorators";

const ColorScheme = Discourse.Model.extend(Ember.Copyable, {
  init: function() {
    this._super(...arguments);
    this.startTrackingChanges();
  },

  @computed
  description() {
    return "" + this.name;
  },

  startTrackingChanges: function() {
    this.set("originals", {
      name: this.get("name")
    });
  },

  schemeJson() {
    let buffer = [];
    this.get("colors").forEach(c => {
      buffer.push(`  "${c.get("name")}": "${c.get("hex")}"`);
    });

    return [`"${this.get("name")}": {`, buffer.join(",\n"), "}"].join("\n");
  },

  copy: function() {
    var newScheme = ColorScheme.create({
      name: this.get("name"),
      can_edit: true,
      colors: Ember.A()
    });
    this.get("colors").forEach(c => {
      newScheme.colors.pushObject(
        ColorSchemeColor.create({
          name: c.get("name"),
          hex: c.get("hex"),
          default_hex: c.get("default_hex")
        })
      );
    });
    return newScheme;
  },

  @computed("name", "colors.@each.changed", "saving")
  changed() {
    if (!this.originals) return false;
    if (this.originals["name"] !== this.get("name")) return true;
    if (
      _.any(this.get("colors"), function(c) {
        return c.get("changed");
      })
    )
      return true;
    return false;
  },

  @computed("changed")
  disableSave(changed) {
    if (this.get("theme_id")) {
      return false;
    }
    return (
      !changed ||
      this.get("saving") ||
      _.any(this.get("colors"), function(c) {
        return !c.get("valid");
      })
    );
  },

  newRecord: Ember.computed.not("id"),

  save: function(opts) {
    if (this.get("is_base") || this.get("disableSave")) return;

    var self = this;
    this.set("savingStatus", I18n.t("saving"));
    this.set("saving", true);

    var data = {};

    if (!opts || !opts.enabledOnly) {
      data.name = this.name;
      data.base_scheme_id = this.get("base_scheme_id");
      data.colors = [];
      this.get("colors").forEach(c => {
        if (!self.id || c.get("changed")) {
          data.colors.pushObject({ name: c.get("name"), hex: c.get("hex") });
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
    ).then(function(result) {
      if (result.id) {
        self.set("id", result.id);
      }
      if (!opts || !opts.enabledOnly) {
        self.startTrackingChanges();
        self.get("colors").forEach(c => c.startTrackingChanges());
      }
      self.set("savingStatus", I18n.t("saved"));
      self.set("saving", false);
      self.notifyPropertyChange("description");
    });
  },

  destroy: function() {
    if (this.id) {
      return ajax("/admin/color_schemes/" + this.id, { type: "DELETE" });
    }
  }
});

var ColorSchemes = Ember.ArrayProxy.extend({});

ColorScheme.reopenClass({
  findAll: function() {
    var colorSchemes = ColorSchemes.create({ content: [], loading: true });
    return ajax("/admin/color_schemes").then(function(all) {
      all.forEach(colorScheme => {
        colorSchemes.pushObject(
          ColorScheme.create({
            id: colorScheme.id,
            name: colorScheme.name,
            is_base: colorScheme.is_base,
            theme_id: colorScheme.theme_id,
            theme_name: colorScheme.theme_name,
            base_scheme_id: colorScheme.base_scheme_id,
            colors: colorScheme.colors.map(function(c) {
              return ColorSchemeColor.create({
                name: c.name,
                hex: c.hex,
                default_hex: c.default_hex
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
