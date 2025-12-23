import { computed, get } from "@ember/object";
import { gt, or } from "@ember/object/computed";
import { isBlank, isEmpty } from "@ember/utils";
import ThemeSettings from "discourse/admin/models/theme-settings";
import ThemeSiteSettings from "discourse/admin/models/theme-site-settings";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

const THEME_UPLOAD_VAR = 2;
const FIELDS_IDS = [0, 1, 5, 6];

export const THEMES = "themes";
export const COMPONENTS = "components";
const SETTINGS_TYPE_ID = 5;

const JS_FILENAME = "discourse/api-initializers/theme-initializer.gjs";

class Theme extends RestModel {
  static munge(json) {
    if (json.settings) {
      json.settings = json.settings.map((setting) =>
        ThemeSettings.create(setting)
      );
    }

    if (json.themeable_site_settings) {
      json.themeable_site_settings = json.themeable_site_settings.map(
        (setting) => ThemeSiteSettings.create(setting)
      );
    }

    return json;
  }

  @trackedArray childThemes;
  @trackedArray parentThemes;
  @trackedArray theme_fields;

  @or("default", "user_selectable") isActive;
  @gt("remote_theme.commits_behind", 0) isPendingUpdates;
  @gt("editedFields.length", 0) hasEditedFields;
  @gt("parent_themes.length", 0) hasParents;

  changed = false;

  @computed("theme_fields.[]")
  get targets() {
    return [
      { id: 0, name: "common" },
      { id: 1, name: "desktop", icon: "desktop" },
      { id: 2, name: "mobile", icon: "mobile-screen-button" },
    ].map((target) => {
      target["edited"] = this.hasEdited(target.name);
      target["error"] = this.hasError(target.name);
      return target;
    });
  }

  @computed("theme_fields.[]")
  get fieldNames() {
    const common = [
      "scss",
      "head_tag",
      "header",
      "after_header",
      "body_tag",
      "footer",
    ];

    return {
      common: [
        ...common,
        "js",
        "color_definitions",
        "embedded_scss",
        "embedded_header",
      ],
      desktop: common,
      mobile: common,
    };
  }

  @computed("fieldNames", "theme_fields.[]", "theme_fields.@each.error")
  get fields() {
    const hash = {};
    Object.keys(this.fieldNames).forEach((target) => {
      hash[target] = this.fieldNames[target].map((fieldName) => {
        const field = {
          name: fieldName,
          edited: this.hasEdited(target, fieldName),
          error: this.hasError(target, fieldName),
        };

        field.translatedName = i18n(`admin.customize.theme.${fieldName}.text`);
        field.title = i18n(`admin.customize.theme.${fieldName}.title`);

        if (fieldName.indexOf("_tag") > 0) {
          field.icon = "far-file-lines";
        }

        return field;
      });
    });
    return hash;
  }

  @computed("theme_fields")
  get themeFields() {
    if (!this.theme_fields) {
      this.set("theme_fields", []);
      return {};
    }

    let hash = {};
    this.theme_fields.forEach((field) => {
      if (!field.type_id || FIELDS_IDS.includes(field.type_id)) {
        hash[this.getKey(field)] = field;
      }
    });
    return hash;
  }

  @computed("theme_fields", "theme_fields.[]")
  get uploads() {
    if (!this.theme_fields) {
      return [];
    }
    return this.theme_fields.filter(
      (f) => f.target === "common" && f.type_id === THEME_UPLOAD_VAR
    );
  }

  @computed("theme_fields", "theme_fields.@each.error")
  get isBroken() {
    return (
      this.theme_fields &&
      this.theme_fields.some((field) => field.error && field.error.length > 0)
    );
  }

  @computed("theme_fields.[]")
  get editedFields() {
    return this.theme_fields?.filter(
      (field) => !isBlank(field.value) && field.type_id !== SETTINGS_TYPE_ID
    );
  }

  @computed("remote_theme.last_error_text")
  get remoteError() {
    if (
      this.remote_theme?.last_error_text &&
      this.remote_theme?.last_error_text?.length > 0
    ) {
      return this.remote_theme?.last_error_text;
    }
  }

  getKey(field) {
    return `${field.target} ${field.name}`;
  }

  hasEdited(target, name) {
    if (name) {
      return !isEmpty(this.getField(target, name));
    } else {
      let fields = this.theme_fields || [];
      return fields.some(
        (field) => field.target === target && !isEmpty(field.value)
      );
    }
  }

  hasError(target, name) {
    return this.theme_fields
      .filter((f) => f.target === target && (!name || name === f.name))
      .some((f) => f.error);
  }

  getError(target, name) {
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? field.error : "";
  }

  getField(target, name) {
    if (target === "common" && name === "js") {
      target = "extra_js";
      name = JS_FILENAME;
    }
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? field.value : "";
  }

  removeField(field) {
    this.set("changed", true);

    field.upload_id = null;
    field.value = null;

    return this.saveChanges("theme_fields");
  }

  setField(target, name, value, upload_id, type_id) {
    this.set("changed", true);
    let themeFields = this.themeFields;
    let field = { name, target, value, upload_id, type_id };
    if (field.name === "js" && target === "common") {
      field.target = "extra_js";
      field.name = JS_FILENAME;
    }

    // slow path for uploads and so on
    if (type_id && type_id > 1) {
      let fields = this.theme_fields;
      let existing = fields.find(
        (f) => f.target === target && f.name === name && f.type_id === type_id
      );
      if (existing) {
        existing.value = value;
        existing.upload_id = upload_id;
      } else {
        fields.push(field);
      }
      return;
    }

    // fast path
    let key = this.getKey({ target, name });
    let existingField = themeFields[key];
    if (!existingField) {
      this.theme_fields.push(field);
      themeFields[key] = field;
    } else {
      const changed =
        (isEmpty(existingField.value) && !isEmpty(value)) ||
        (isEmpty(value) && !isEmpty(existingField.value));

      existingField.value = value;
      if (changed) {
        // Observing theme_fields.@each.value is too slow, so manually notify
        // if the value goes to/from blank
        this.notifyPropertyChange("theme_fields.[]");
      }
    }
  }

  @computed("childThemes.[]")
  get child_theme_ids() {
    if (this.childThemes) {
      return this.childThemes?.map((theme) => get(theme, "id"));
    }
  }

  @computed("recentlyInstalled", "component", "hasParents")
  get warnUnassignedComponent() {
    return this.recentlyInstalled && this.component && !this.hasParents;
  }

  removeChildTheme(theme) {
    removeValueFromArray(this.childThemes, theme);
    return this.saveChanges("child_theme_ids");
  }

  addChildTheme(theme) {
    let childThemes = this.childThemes;
    if (!childThemes) {
      childThemes = [];
      this.set("childThemes", childThemes);
    }

    removeValueFromArray(childThemes, theme);
    childThemes.push(theme);

    return this.saveChanges("child_theme_ids");
  }

  addParentTheme(theme) {
    let parentThemes = this.parentThemes;
    if (!parentThemes) {
      parentThemes = [];
      this.set("parentThemes", parentThemes);
    }

    addUniqueValueToArray(parentThemes, theme);
  }

  checkForUpdates() {
    return this.save({ remote_check: true }).then(() =>
      this.set("changed", false)
    );
  }

  updateToLatest() {
    return this.save({ remote_update: true }).then(() =>
      this.set("changed", false)
    );
  }

  saveChanges() {
    const hash = this.getProperties.apply(this, arguments);
    return this.save(hash)
      .then(() => true)
      .finally(() => this.set("changed", false))
      .catch(popupAjaxError);
  }
}

export default Theme;
