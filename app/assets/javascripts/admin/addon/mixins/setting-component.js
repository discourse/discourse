import { warn } from "@ember/debug";
import { action, computed } from "@ember/object";
import { alias, oneWay } from "@ember/object/computed";
import Mixin from "@ember/object/mixin";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isNone } from "@ember/utils";
import { Promise } from "rsvp";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import { ajax } from "discourse/lib/ajax";
import { fmt, propertyNotEqual } from "discourse/lib/computed";
import {
  DEFAULT_USER_PREFERENCES,
  SITE_SETTING_REQUIRES_CONFIRMATION_TYPES,
} from "discourse/lib/constants";
import { deepEqual } from "discourse/lib/object";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { splitString } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import SiteSettingDefaultCategoriesModal from "../components/modal/site-setting-default-categories";

const CUSTOM_TYPES = [
  "bool",
  "integer",
  "enum",
  "list",
  "url_list",
  "host_list",
  "category_list",
  "value_list",
  "category",
  "uploaded_image_list",
  "compact_list",
  "secret_list",
  "upload",
  "group_list",
  "tag_list",
  "tag_group_list",
  "color",
  "simple_list",
  "emoji_list",
  "named_list",
  "file_size_restriction",
  "file_types_list",
  "font_list",
];

const AUTO_REFRESH_ON_SAVE = ["logo", "logo_small", "large_icon"];

export default Mixin.create({
  modal: service(),
  router: service(),
  site: service(),
  dialog: service(),
  siteSettingChangeTracker: service(),
  attributeBindings: ["setting.setting:data-setting"],
  classNameBindings: [":row", ":setting", "overridden", "typeClass"],
  validationMessage: null,
  isSaving: false,

  content: alias("setting"),
  isSecret: oneWay("setting.secret"),
  componentName: fmt("typeClass", "site-settings/%@"),
  overridden: propertyNotEqual("setting.default", "buffered.value"),

  didInsertElement() {
    this._super(...arguments);
    this.element.addEventListener("keydown", this._handleKeydown);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.siteSettingChangeTracker.remove(this);
    this.element.removeEventListener("keydown", this._handleKeydown);
  },

  displayDescription: computed("componentType", function () {
    return this.componentType !== "bool";
  }),

  dirty: computed("buffered.value", "setting.value", function () {
    let bufferVal = this.get("buffered.value");
    let settingVal = this.setting?.value;

    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    const dirty = !deepEqual(bufferVal, settingVal);

    if (dirty) {
      this.siteSettingChangeTracker.add(this);
    } else {
      this.siteSettingChangeTracker.remove(this);
    }

    return dirty;
  }),

  preview: computed("setting", "buffered.value", function () {
    const setting = this.setting;
    const value = this.get("buffered.value");
    const preview = setting.preview;
    if (preview) {
      const escapedValue = preview.replace(/\{\{value\}\}/g, value);
      return htmlSafe(`<div class='preview'>${escapedValue}</div>`);
    }
  }),

  typeClass: computed("componentType", function () {
    const componentType = this.componentType;
    return componentType.replace(/\_/g, "-");
  }),

  settingName: computed("setting.setting", "setting.label", function () {
    return humanizedSettingName(this.setting.setting, this.setting.label);
  }),

  componentType: computed("type", function () {
    const type = this.type;
    return CUSTOM_TYPES.includes(type) ? type : "string";
  }),

  type: computed("setting", function () {
    const setting = this.setting;
    if (setting.type === "list" && setting.list_type) {
      return `${setting.list_type}_list`;
    }

    return setting.type;
  }),

  allowAny: computed("setting.anyValue", function () {
    const anyValue = this.setting?.anyValue;
    return anyValue !== false;
  }),

  bufferedValues: computed("buffered.value", function () {
    const value = this.get("buffered.value");
    return splitString(value, "|");
  }),

  defaultValues: computed("setting.defaultValues", function () {
    const value = this.setting?.defaultValues;
    return splitString(value, "|");
  }),

  defaultIsAvailable: computed("defaultValues", "bufferedValues", function () {
    const defaultValues = this.defaultValues;
    const bufferedValues = this.bufferedValues;
    return (
      defaultValues.length > 0 &&
      !defaultValues.every((value) => bufferedValues.includes(value))
    );
  }),

  settingEditButton: computed("setting", function () {
    const setting = this.setting;
    if (setting.json_schema) {
      return {
        action: () => {
          this.modal.show(JsonSchemaEditorModal, {
            model: {
              updateValue: (value) => {
                this.buffered.set("value", value);
              },
              value: this.buffered.get("value"),
              settingName: setting.setting,
              jsonSchema: setting.json_schema,
            },
          });
        },
        label: "admin.site_settings.json_schema.edit",
        icon: "pencil",
      };
    } else if (setting.objects_schema) {
      return {
        action: () => {
          this.router.transitionTo(
            "adminCustomizeThemes.show.schema",
            setting.setting
          );
        },
        label: "admin.customize.theme.edit_objects_theme_setting",
        icon: "pencil",
      };
    }
  }),

  disableSaveButton: computed("isSaving", "validationMessage", function () {
    return !!this.validationMessage || this.isSaving;
  }),

  disableUndoButton: computed("isSaving", function () {
    return !!this.isSaving;
  }),

  requiresReload() {
    return AUTO_REFRESH_ON_SAVE.includes(this.setting.setting);
  },

  requiresConfirmation() {
    return (
      this.buffered.get("requires_confirmation") ===
      SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple
    );
  },

  affectsExistingUsers() {
    return DEFAULT_USER_PREFERENCES.includes(this.buffered.get("setting"));
  },

  confirmChanges() {
    const settingKey = this.buffered.get("setting");

    return new Promise((resolve) => {
      // Fallback is needed in case the setting does not have a custom confirmation
      // prompt/confirm defined.
      this.dialog.alert({
        message: i18n(
          `admin.site_settings.requires_confirmation_messages.${settingKey}.prompt`,
          {
            translatedFallback: i18n(
              "admin.site_settings.requires_confirmation_messages.default.prompt"
            ),
          }
        ),
        buttons: [
          {
            label: i18n(
              `admin.site_settings.requires_confirmation_messages.${settingKey}.confirm`,
              {
                translatedFallback: i18n(
                  "admin.site_settings.requires_confirmation_messages.default.confirm"
                ),
              }
            ),
            class: "btn-primary",
            action: () => resolve(true),
          },
          {
            label: i18n("no_value"),
            class: "btn-default",
            action: () => resolve(false),
          },
        ],
      });
    });
  },

  async configureBackfill() {
    const key = this.buffered.get("setting");

    const data = {
      [key]: this.buffered.get("value"),
    };

    const result = await ajax(`/admin/site_settings/${key}/user_count.json`, {
      type: "PUT",
      data,
    });

    const count = result.user_count;

    if (count > 0) {
      await this.modal.show(SiteSettingDefaultCategoriesModal, {
        model: {
          siteSetting: { count, key: key.replaceAll("_", " ") },
          setUpdateExistingUsers: this.setUpdateExistingUsers,
        },
      });
    }
  },

  update: action(async function () {
    if (this.requiresConfirmation()) {
      const confirm = await this.confirmChanges();

      if (!confirm) {
        return;
      }
    }

    if (this.affectsExistingUsers()) {
      await this.configureBackfill();
    }

    await this.save();
  }),

  setUpdateExistingUsers: action(function (value) {
    this.updateExistingUsers = value;
  }),

  save: action(async function () {
    try {
      this.set("isSaving", true);

      await this._save();

      this.set("validationMessage", null);
      this.buffered.applyChanges();
      if (this.requiresReload()) {
        this.afterSave();
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = htmlSafe(errorString);
        }

        this.set("validationMessage", errorString);
      } else {
        this.set("validationMessage", i18n("generic_error"));
      }
    } finally {
      this.set("isSaving", false);
    }
  }),

  changeValueCallback: action(function (value) {
    this.set("buffered.value", value);
  }),

  setValidationMessage: action(function (message) {
    this.set("validationMessage", message);
  }),

  cancel: action(function () {
    this.buffered.discardChanges();
    this.set("validationMessage", null);
  }),

  resetDefault: action(function () {
    this.set("buffered.value", this.setting.default);
    this.set("validationMessage", null);
  }),

  toggleSecret: action(function () {
    this.toggleProperty("isSecret");
  }),

  setDefaultValues: action(function () {
    this.set(
      "buffered.value",
      this.bufferedValues.concat(this.defaultValues).uniq().join("|")
    );
    this.set("validationMessage", null);
    return false;
  }),

  _handleKeydown: action(function (event) {
    if (
      event.key === "Enter" &&
      event.target.classList.contains("input-setting-string")
    ) {
      this.save();
    }
  }),

  async _save() {
    warn("You should define a `_save` method", {
      id: "discourse.setting-component.missing-save",
    });
  },
});
