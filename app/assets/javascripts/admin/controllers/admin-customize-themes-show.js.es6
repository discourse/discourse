import { default as computed } from "ember-addons/ember-computed-decorators";
import { url } from "discourse/lib/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import ThemeSettings from "admin/models/theme-settings";
import { THEMES, COMPONENTS } from "admin/models/theme";

const THEME_UPLOAD_VAR = 2;

export default Ember.Controller.extend({
  downloadUrl: url("model.id", "/admin/themes/%@"),
  previewUrl: url("model.id", "/admin/themes/%@/preview"),
  addButtonDisabled: Ember.computed.empty("selectedChildThemeId"),
  editRouteName: "adminCustomizeThemes.edit",

  @computed("model", "allThemes", "model.component")
  parentThemes(model, allThemes) {
    if (!model.get("component")) {
      return null;
    }
    const parents = allThemes.filter(theme =>
      _.contains(theme.get("childThemes"), model)
    );
    return parents.length === 0 ? null : parents;
  },

  @computed("model.editedFields")
  editedFieldsFormatted() {
    const descriptions = [];
    ["common", "desktop", "mobile"].forEach(target => {
      const fields = this.editedFieldsForTarget(target);
      if (fields.length < 1) {
        return;
      }
      let resultString = I18n.t("admin.customize.theme." + target);
      const formattedFields = fields
        .map(f => I18n.t("admin.customize.theme." + f.name + ".text"))
        .join(" , ");
      resultString += `: ${formattedFields}`;
      descriptions.push(resultString);
    });
    return descriptions;
  },

  @computed("colorSchemeId", "model.color_scheme_id")
  colorSchemeChanged(colorSchemeId, existingId) {
    colorSchemeId = colorSchemeId === null ? null : parseInt(colorSchemeId);
    return colorSchemeId !== existingId;
  },

  @computed("availableChildThemes", "model.childThemes.[]", "model")
  selectableChildThemes(available, childThemes) {
    if (available) {
      const themes = !childThemes
        ? available
        : available.filter(theme => childThemes.indexOf(theme) === -1);
      return themes.length === 0 ? null : themes;
    }
  },

  @computed("allThemes", "model.component", "model")
  availableChildThemes(allThemes) {
    if (!this.get("model.component")) {
      const themeId = this.get("model.id");
      return allThemes.filter(
        theme => theme.get("id") !== themeId && theme.get("component")
      );
    }
  },

  @computed("model.component")
  convertKey(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}`;
  },

  @computed("model.component")
  convertIcon(component) {
    return component ? "cube" : "";
  },

  @computed("model.component")
  convertTooltip(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}_tooltip`;
  },

  @computed("model.settings")
  settings(settings) {
    return settings.map(setting => ThemeSettings.create(setting));
  },

  hasSettings: Ember.computed.notEmpty("settings"),

  @computed("model.translations")
  translations(translations) {
    return translations.map(setting => ThemeSettings.create(setting));
  },

  hasTranslations: Ember.computed.notEmpty("translations"),

  @computed("model.remoteError", "updatingRemote")
  showRemoteError(errorMessage, updating) {
    return errorMessage && !updating;
  },

  editedFieldsForTarget(target) {
    return this.get("model.editedFields").filter(
      field => field.target === target
    );
  },

  commitSwitchType() {
    const model = this.get("model");
    const newValue = !model.get("component");
    model.set("component", newValue);

    if (newValue) {
      this.set("parentController.currentTab", COMPONENTS);
    } else {
      this.set("parentController.currentTab", THEMES);
    }

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

        this.get("parentController.model.content").forEach(theme => {
          const children = Ember.makeArray(theme.get("childThemes"));
          const rawChildren = Ember.makeArray(theme.get("child_themes"));
          const index = children ? children.indexOf(model) : -1;
          if (index > -1) {
            children.splice(index, 1);
            rawChildren.splice(index, 1);
            theme.setProperties({
              childThemes: children,
              child_themes: rawChildren
            });
          }
        });
      })
      .catch(popupAjaxError);
  },
  transitionToEditRoute() {
    this.transitionToRoute(
      this.get("editRouteName"),
      this.get("model.id"),
      "common",
      "scss"
    );
  },
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
      if (this.get("model.remote_theme")) {
        bootbox.confirm(
          I18n.t("admin.customize.theme.edit_confirm"),
          result => {
            if (result) {
              this.transitionToEditRoute();
            }
          }
        );
      } else {
        this.transitionToEditRoute();
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
      const relatives = this.get("model.component")
        ? this.get("parentThemes")
        : this.get("model.childThemes");
      if (relatives && relatives.length > 0) {
        const names = relatives.map(relative => relative.get("name"));
        bootbox.confirm(
          I18n.t(`${this.get("convertKey")}_alert`, {
            relatives: names.join(", ")
          }),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          result => {
            if (result) {
              this.commitSwitchType();
            }
          }
        );
      } else {
        this.commitSwitchType();
      }
    }
  }
});
