import { get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { or, gt } from "@ember/object/computed";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { url } from "discourse/lib/computed";

const THEME_UPLOAD_VAR = 2;
const FIELDS_IDS = [0, 1, 5];

export const THEMES = "themes";
export const COMPONENTS = "components";
const SETTINGS_TYPE_ID = 5;

const Theme = RestModel.extend({
  isActive: or("default", "user_selectable"),
  isPendingUpdates: gt("remote_theme.commits_behind", 0),
  hasEditedFields: gt("editedFields.length", 0),
  hasParents: gt("parent_themes.length", 0),
  diffLocalChangesUrl: url("id", "/admin/themes/%@/diff_local_changes"),

  @discourseComputed("theme_fields.[]")
  targets() {
    return [
      { id: 0, name: "common" },
      { id: 1, name: "desktop", icon: "desktop" },
      { id: 2, name: "mobile", icon: "mobile-alt" },
      { id: 3, name: "settings", icon: "cog", advanced: true },
      {
        id: 4,
        name: "translations",
        icon: "globe",
        advanced: true,
        customNames: true
      },
      {
        id: 5,
        name: "extra_scss",
        icon: "paint-brush",
        advanced: true,
        customNames: true
      }
    ].map(target => {
      target["edited"] = this.hasEdited(target.name);
      target["error"] = this.hasError(target.name);
      return target;
    });
  },

  @discourseComputed("theme_fields.[]")
  fieldNames() {
    const common = [
      "scss",
      "head_tag",
      "header",
      "after_header",
      "body_tag",
      "footer"
    ];

    const scss_fields = (this.theme_fields || [])
      .filter(f => f.target === "extra_scss" && f.name !== "")
      .map(f => f.name);

    if (scss_fields.length < 1) {
      scss_fields.push("importable_scss");
    }

    return {
      common: [...common, "embedded_scss"],
      desktop: common,
      mobile: common,
      settings: ["yaml"],
      translations: [
        "en",
        ...(this.theme_fields || [])
          .filter(f => f.target === "translations" && f.name !== "en")
          .map(f => f.name)
      ],
      extra_scss: scss_fields
    };
  },

  @discourseComputed(
    "fieldNames",
    "theme_fields.[]",
    "theme_fields.@each.error"
  )
  fields(fieldNames) {
    const hash = {};
    Object.keys(fieldNames).forEach(target => {
      hash[target] = fieldNames[target].map(fieldName => {
        const field = {
          name: fieldName,
          edited: this.hasEdited(target, fieldName),
          error: this.hasError(target, fieldName)
        };

        if (target === "translations" || target === "extra_scss") {
          field.translatedName = fieldName;
        } else {
          field.translatedName = I18n.t(
            `admin.customize.theme.${fieldName}.text`
          );
          field.title = I18n.t(`admin.customize.theme.${fieldName}.title`);
        }

        if (fieldName.indexOf("_tag") > 0) {
          field.icon = "far-file-alt";
        }

        return field;
      });
    });
    return hash;
  },

  @discourseComputed("theme_fields")
  themeFields(fields) {
    if (!fields) {
      this.set("theme_fields", []);
      return {};
    }

    let hash = {};
    fields.forEach(field => {
      if (!field.type_id || FIELDS_IDS.includes(field.type_id)) {
        hash[this.getKey(field)] = field;
      }
    });
    return hash;
  },

  @discourseComputed("theme_fields", "theme_fields.[]")
  uploads(fields) {
    if (!fields) {
      return [];
    }
    return fields.filter(
      f => f.target === "common" && f.type_id === THEME_UPLOAD_VAR
    );
  },

  @discourseComputed("theme_fields", "theme_fields.@each.error")
  isBroken(fields) {
    return fields && fields.any(field => field.error && field.error.length > 0);
  },

  @discourseComputed("theme_fields.[]")
  editedFields(fields) {
    return fields.filter(
      field => !Ember.isBlank(field.value) && field.type_id !== SETTINGS_TYPE_ID
    );
  },

  @discourseComputed("remote_theme.last_error_text")
  remoteError(errorText) {
    if (errorText && errorText.length > 0) {
      return errorText;
    }
  },

  getKey(field) {
    return `${field.target} ${field.name}`;
  },

  hasEdited(target, name) {
    if (name) {
      return !isEmpty(this.getField(target, name));
    } else {
      let fields = this.theme_fields || [];
      return fields.any(
        field => field.target === target && !isEmpty(field.value)
      );
    }
  },

  hasError(target, name) {
    return this.theme_fields
      .filter(f => f.target === target && (!name || name === f.name))
      .any(f => f.error);
  },

  getError(target, name) {
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? field.error : "";
  },

  getField(target, name) {
    let themeFields = this.themeFields;
    let key = this.getKey({ target, name });
    let field = themeFields[key];
    return field ? field.value : "";
  },

  removeField(field) {
    this.set("changed", true);

    field.upload_id = null;
    field.value = null;

    return this.saveChanges("theme_fields");
  },

  setField(target, name, value, upload_id, type_id) {
    this.set("changed", true);
    let themeFields = this.themeFields;
    let field = { name, target, value, upload_id, type_id };

    // slow path for uploads and so on
    if (type_id && type_id > 1) {
      let fields = this.theme_fields;
      let existing = fields.find(
        f => f.target === target && f.name === name && f.type_id === type_id
      );
      if (existing) {
        existing.value = value;
        existing.upload_id = upload_id;
      } else {
        fields.pushObject(field);
      }
      return;
    }

    // fast path
    let key = this.getKey({ target, name });
    let existingField = themeFields[key];
    if (!existingField) {
      this.theme_fields.pushObject(field);
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
  },

  @discourseComputed("childThemes.[]")
  child_theme_ids(childThemes) {
    if (childThemes) {
      return childThemes.map(theme => get(theme, "id"));
    }
  },

  removeChildTheme(theme) {
    const childThemes = this.childThemes;
    childThemes.removeObject(theme);
    return this.saveChanges("child_theme_ids");
  },

  addChildTheme(theme) {
    let childThemes = this.childThemes;
    if (!childThemes) {
      childThemes = [];
      this.set("childThemes", childThemes);
    }
    childThemes.removeObject(theme);
    childThemes.pushObject(theme);
    return this.saveChanges("child_theme_ids");
  },

  addParentTheme(theme) {
    let parentThemes = this.parentThemes;
    if (!parentThemes) {
      parentThemes = [];
      this.set("parentThemes", parentThemes);
    }
    parentThemes.addObject(theme);
  },

  @discourseComputed("name", "default")
  description: function(name, isDefault) {
    if (isDefault) {
      return I18n.t("admin.customize.theme.default_name", { name: name });
    } else {
      return name;
    }
  },

  checkForUpdates() {
    return this.save({ remote_check: true }).then(() =>
      this.set("changed", false)
    );
  },

  updateToLatest() {
    return ajax(this.diffLocalChangesUrl).then(json => {
      if (json && json.error) {
        bootbox.alert(
          I18n.t("generic_error_with_reason", {
            error: json.error
          })
        );
      } else if (json && json.diff) {
        bootbox.confirm(
          I18n.t("admin.customize.theme.update_confirm") +
            `<pre><code class="diff">${escapeExpression(
              json.diff
            )}</code></pre>`,
          I18n.t("cancel"),
          I18n.t("admin.customize.theme.update_confirm_yes"),
          result => {
            if (result) {
              return this.save({ remote_update: true }).then(() =>
                this.set("changed", false)
              );
            }
          }
        );
        highlightSyntax();
      } else {
        return this.save({ remote_update: true }).then(() =>
          this.set("changed", false)
        );
      }
    });
  },

  changed: false,

  saveChanges() {
    const hash = this.getProperties.apply(this, arguments);
    return this.save(hash)
      .finally(() => this.set("changed", false))
      .catch(popupAjaxError);
  },

  saveSettings(name, value) {
    const settings = {};
    settings[name] = value;
    return this.save({ settings });
  },

  saveTranslation(name, value) {
    return this.save({ translations: { [name]: value } });
  }
});

export default Theme;
