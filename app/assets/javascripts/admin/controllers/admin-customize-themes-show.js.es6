import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import { url } from "discourse/lib/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import ThemeSettings from "admin/models/theme-settings";

const THEME_UPLOAD_VAR = 2;
const SETTINGS_TYPE_ID = 5;

export default Ember.Controller.extend({
  editRouteName: "adminCustomizeThemes.edit",

  @observes("allowChildThemes")
  setSelectedThemeId() {
    const available = this.get("selectableChildThemes");
    if (
      !this.get("selectedChildThemeId") &&
      available &&
      available.length > 0
    ) {
      this.set("selectedChildThemeId", available[0].get("id"));
    }
  },

  @computed("model", "allThemes", "model.component")
  parentThemes(model, allThemes) {
    if (!model.get("component")) {
      return null;
    }
    let parents = allThemes.filter(theme =>
      _.contains(theme.get("childThemes"), model)
    );
    return parents.length === 0 ? null : parents;
  },

  @computed("model.theme_fields.@each")
  hasEditedFields(fields) {
    return fields.any(
      f => !Em.isBlank(f.value) && f.type_id !== SETTINGS_TYPE_ID
    );
  },

  @computed("model.theme_fields.@each")
  editedDescriptions(fields) {
    let descriptions = [];
    let description = target => {
      let current = fields.filter(
        field => field.target === target && !Em.isBlank(field.value)
      );
      if (current.length > 0) {
        let text = I18n.t("admin.customize.theme." + target);
        let localized = current.map(f =>
          I18n.t("admin.customize.theme." + f.name + ".text")
        );
        return text + ": " + localized.join(" , ");
      }
    };
    ["common", "desktop", "mobile"].forEach(target => {
      descriptions.push(description(target));
    });
    return descriptions.reject(d => Em.isBlank(d));
  },

  previewUrl: url("model.id", "/admin/themes/%@/preview"),

  @computed("colorSchemeId", "model.color_scheme_id")
  colorSchemeChanged(colorSchemeId, existingId) {
    colorSchemeId = colorSchemeId === null ? null : parseInt(colorSchemeId);
    return colorSchemeId !== existingId;
  },

  @computed(
    "availableChildThemes",
    "model.childThemes.@each",
    "model",
    "allowChildThemes"
  )
  selectableChildThemes(available, childThemes, allowChildThemes) {
    if (!allowChildThemes && (!childThemes || childThemes.length === 0)) {
      return null;
    }

    let themes = [];
    available.forEach(t => {
      if (!childThemes || childThemes.indexOf(t) === -1) {
        themes.push(t);
      }
    });
    return themes.length === 0 ? null : themes;
  },

  @computed("allThemes", "allThemes.length", "model.component", "model")
  availableChildThemes(allThemes, count, component) {
    if (count === 1 || component) {
      return null;
    }

    const themeId = this.get("model.id");

    let themes = [];
    allThemes.forEach(theme => {
      if (themeId !== theme.get("id") && theme.get("component")) {
        themes.push(theme);
      }
    });

    return themes;
  },

  @computed("model.component")
  switchKey(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.switch_${type}`;
  },

  @computed("model.settings")
  settings(settings) {
    return settings.map(setting => ThemeSettings.create(setting));
  },

  @computed("settings")
  hasSettings(settings) {
    return settings.length > 0;
  },

  downloadUrl: url("model.id", "/admin/themes/%@"),

  actions: {
    updateToLatest() {
      this.set("updatingRemote", true);
      this.get("model")
        .updateToLatest()
        .catch(popupAjaxError)
        .finally(() => {
          this.set("updatingRemote", false);
        });
    },

    checkForThemeUpdates() {
      this.set("updatingRemote", true);
      this.get("model")
        .checkForUpdates()
        .catch(popupAjaxError)
        .finally(() => {
          this.set("updatingRemote", false);
        });
    },

    addUploadModal() {
      showModal("admin-add-upload", { admin: true, name: "" });
    },

    addUpload(info) {
      let model = this.get("model");
      model.setField("common", info.name, "", info.upload_id, THEME_UPLOAD_VAR);
      model.saveChanges("theme_fields").catch(e => popupAjaxError(e));
    },

    cancelChangeScheme() {
      this.set("colorSchemeId", this.get("model.color_scheme_id"));
    },
    changeScheme() {
      let schemeId = this.get("colorSchemeId");
      this.set(
        "model.color_scheme_id",
        schemeId === null ? null : parseInt(schemeId)
      );
      this.get("model").saveChanges("color_scheme_id");
    },
    startEditingName() {
      this.set("oldName", this.get("model.name"));
      this.set("editingName", true);
    },
    cancelEditingName() {
      this.set("model.name", this.get("oldName"));
      this.set("editingName", false);
    },
    finishedEditingName() {
      this.get("model").saveChanges("name");
      this.set("editingName", false);
    },

    editTheme() {
      let edit = () =>
        this.transitionToRoute(
          this.get("editRouteName"),
          this.get("model.id"),
          "common",
          "scss"
        );

      if (this.get("model.remote_theme")) {
        bootbox.confirm(
          I18n.t("admin.customize.theme.edit_confirm"),
          result => {
            if (result) {
              edit();
            }
          }
        );
      } else {
        edit();
      }
    },

    applyDefault() {
      const model = this.get("model");
      model.saveChanges("default").then(() => {
        if (model.get("default")) {
          this.get("allThemes").forEach(theme => {
            if (theme !== model && theme.get("default")) {
              theme.set("default", false);
            }
          });
        }
      });
    },

    applyUserSelectable() {
      this.get("model").saveChanges("user_selectable");
    },

    addChildTheme() {
      let themeId = parseInt(this.get("selectedChildThemeId"));
      let theme = this.get("allThemes").findBy("id", themeId);
      this.get("model").addChildTheme(theme);
    },

    removeUpload(upload) {
      return bootbox.confirm(
        I18n.t("admin.customize.theme.delete_upload_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.get("model").removeField(upload);
          }
        }
      );
    },

    removeChildTheme(theme) {
      this.get("model").removeChildTheme(theme);
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("admin.customize.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            const model = this.get("model");
            model.destroyRecord().then(() => {
              this.get("allThemes").removeObject(model);
              this.transitionToRoute("adminCustomizeThemes");
            });
          }
        }
      );
    },

    switchType() {
      return bootbox.confirm(
        I18n.t(`${this.get("switchKey")}_alert`),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            const model = this.get("model");
            model.set("component", !model.get("component"));
            model
              .saveChanges("component")
              .then(() => {
                this.set("colorSchemeId", null);
                model.setProperties({
                  default: false,
                  color_scheme_id: null,
                  user_selectable: false,
                  child_themes: [],
                  childThemes: []
                });
              })
              .catch(popupAjaxError);
          }
        }
      );
    }
  }
});
