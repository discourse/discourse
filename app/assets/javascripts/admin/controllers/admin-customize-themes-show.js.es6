import { makeArray } from "discourse-common/lib/helpers";
import {
  empty,
  filterBy,
  match,
  mapBy,
  notEmpty
} from "@ember/object/computed";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { url } from "discourse/lib/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import ThemeSettings from "admin/models/theme-settings";
import { THEMES, COMPONENTS } from "admin/models/theme";
import EmberObject from "@ember/object";

const THEME_UPLOAD_VAR = 2;

export default Controller.extend({
  downloadUrl: url("model.id", "/admin/customize/themes/%@/export"),
  previewUrl: url("model.id", "/admin/themes/%@/preview"),
  addButtonDisabled: empty("selectedChildThemeId"),
  editRouteName: "adminCustomizeThemes.edit",
  parentThemesNames: mapBy("model.parentThemes", "name"),
  availableParentThemes: filterBy("allThemes", "component", false),
  availableActiveParentThemes: filterBy("availableParentThemes", "isActive"),
  availableThemesNames: mapBy("availableParentThemes", "name"),
  availableActiveThemesNames: mapBy("availableActiveParentThemes", "name"),
  availableActiveChildThemes: filterBy("availableChildThemes", "hasParents"),
  availableComponentsNames: mapBy("availableChildThemes", "name"),
  availableActiveComponentsNames: mapBy("availableActiveChildThemes", "name"),
  childThemesNames: mapBy("model.childThemes", "name"),

  @discourseComputed("model.editedFields")
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

  @discourseComputed("colorSchemeId", "model.color_scheme_id")
  colorSchemeChanged(colorSchemeId, existingId) {
    colorSchemeId = colorSchemeId === null ? null : parseInt(colorSchemeId, 10);
    return colorSchemeId !== existingId;
  },

  @discourseComputed("availableChildThemes", "model.childThemes.[]", "model")
  selectableChildThemes(available, childThemes) {
    if (available) {
      const themes = !childThemes
        ? available
        : available.filter(theme => childThemes.indexOf(theme) === -1);
      return themes.length === 0 ? null : themes;
    }
  },

  @discourseComputed("model.parentThemes.[]")
  relativesSelectorSettingsForComponent() {
    return EmberObject.create({
      list_type: "compact",
      type: "list",
      preview: null,
      anyValue: false,
      setting: "parent_theme_ids",
      label: I18n.t("admin.customize.theme.component_on_themes"),
      choices: this.availableThemesNames,
      default: this.parentThemesNames.join("|"),
      value: this.parentThemesNames.join("|"),
      defaultValues: this.availableActiveThemesNames.join("|"),
      allThemes: this.allThemes,
      setDefaultValuesLabel: I18n.t("admin.customize.theme.add_all_themes")
    });
  },

  @discourseComputed("model.parentThemes.[]")
  relativesSelectorSettingsForTheme() {
    return EmberObject.create({
      list_type: "compact",
      type: "list",
      preview: null,
      anyValue: false,
      setting: "child_theme_ids",
      label: I18n.t("admin.customize.theme.included_components"),
      choices: this.availableComponentsNames,
      default: this.childThemesNames.join("|"),
      value: this.childThemesNames.join("|"),
      defaultValues: this.availableActiveComponentsNames.join("|"),
      allThemes: this.allThemes,
      setDefaultValuesLabel: I18n.t("admin.customize.theme.add_all")
    });
  },

  @discourseComputed("allThemes", "model.component", "model")
  availableChildThemes(allThemes) {
    if (!this.get("model.component")) {
      const themeId = this.get("model.id");
      return allThemes.filter(
        theme => theme.get("id") !== themeId && theme.get("component")
      );
    }
  },

  @discourseComputed("model.component")
  convertKey(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}`;
  },

  @discourseComputed("model.component")
  convertIcon(component) {
    return component ? "cube" : "";
  },

  @discourseComputed("model.component")
  convertTooltip(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}_tooltip`;
  },

  @discourseComputed("model.settings")
  settings(settings) {
    return settings.map(setting => ThemeSettings.create(setting));
  },

  hasSettings: notEmpty("settings"),

  @discourseComputed("model.translations")
  translations(translations) {
    return translations.map(setting => ThemeSettings.create(setting));
  },

  hasTranslations: notEmpty("translations"),

  @discourseComputed("model.remoteError", "updatingRemote")
  showRemoteError(errorMessage, updating) {
    return errorMessage && !updating;
  },

  editedFieldsForTarget(target) {
    return this.get("model.editedFields").filter(
      field => field.target === target
    );
  },

  commitSwitchType() {
    const model = this.model;
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
          const children = makeArray(theme.get("childThemes"));
          const rawChildren = makeArray(theme.get("child_themes"));
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
      this.editRouteName,
      this.get("model.id"),
      "common",
      "scss"
    );
  },
  sourceIsHttp: match("model.remote_theme.remote_url", /^http(s)?:\/\//),
  actions: {
    updateToLatest() {
      this.set("updatingRemote", true);
      this.model
        .updateToLatest()
        .catch(popupAjaxError)
        .finally(() => {
          this.set("updatingRemote", false);
        });
    },

    checkForThemeUpdates() {
      this.set("updatingRemote", true);
      this.model
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
      let model = this.model;
      model.setField("common", info.name, "", info.upload_id, THEME_UPLOAD_VAR);
      model.saveChanges("theme_fields").catch(e => popupAjaxError(e));
    },

    cancelChangeScheme() {
      this.set("colorSchemeId", this.get("model.color_scheme_id"));
    },
    changeScheme() {
      let schemeId = this.colorSchemeId;
      this.set(
        "model.color_scheme_id",
        schemeId === null ? null : parseInt(schemeId, 10)
      );
      this.model.saveChanges("color_scheme_id");
    },
    startEditingName() {
      this.set("oldName", this.get("model.name"));
      this.set("editingName", true);
    },
    cancelEditingName() {
      this.set("model.name", this.oldName);
      this.set("editingName", false);
    },
    finishedEditingName() {
      this.model.saveChanges("name");
      this.set("editingName", false);
    },

    editTheme() {
      if (this.get("model.remote_theme.is_git")) {
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
      const model = this.model;
      model.saveChanges("default").then(() => {
        if (model.get("default")) {
          this.allThemes.forEach(theme => {
            if (theme !== model && theme.get("default")) {
              theme.set("default", false);
            }
          });
        }
      });
    },

    applyUserSelectable() {
      this.model.saveChanges("user_selectable");
    },

    addChildTheme() {
      let themeId = parseInt(this.selectedChildThemeId, 10);
      let theme = this.allThemes.findBy("id", themeId);
      this.model.addChildTheme(theme).then(() => this.store.findAll("theme"));
    },

    removeUpload(upload) {
      return bootbox.confirm(
        I18n.t("admin.customize.theme.delete_upload_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.model.removeField(upload);
          }
        }
      );
    },

    removeChildTheme(theme) {
      this.model
        .removeChildTheme(theme)
        .then(() => this.store.findAll("theme"));
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("admin.customize.delete_confirm", {
          theme_name: this.get("model.name")
        }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            const model = this.model;
            model.setProperties({ recentlyInstalled: false });
            model.destroyRecord().then(() => {
              this.allThemes.removeObject(model);
              this.transitionToRoute("adminCustomizeThemes");
            });
          }
        }
      );
    },

    switchType() {
      const relatives = this.get("model.component")
        ? this.parentThemes
        : this.get("model.childThemes");
      if (relatives && relatives.length > 0) {
        const names = relatives.map(relative => relative.get("name"));
        bootbox.confirm(
          I18n.t(`${this.convertKey}_alert`, {
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
    },

    enableComponent() {
      this.model.set("enabled", true);
      this.model
        .saveChanges("enabled")
        .catch(() => this.model.set("enabled", false));
    },

    disableComponent() {
      this.model.set("enabled", false);
      this.model
        .saveChanges("enabled")
        .catch(() => this.model.set("enabled", true));
    }
  }
});
