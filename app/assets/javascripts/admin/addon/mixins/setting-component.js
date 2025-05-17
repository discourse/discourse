import { warn } from "@ember/debug";
import { action, computed } from "@ember/object";
import { alias, oneWay } from "@ember/object/computed";
import Mixin from "@ember/object/mixin";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isNone } from "@ember/utils";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import { fmt, propertyNotEqual } from "discourse/lib/computed";
import { deepEqual } from "discourse/lib/object";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { splitString } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

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

export default Mixin.create({
  modal: service(),
  router: service(),
  site: service(),
  dialog: service(),
  siteSettingChangeTracker: service(),
  attributeBindings: ["setting.setting:data-setting"],
  classNameBindings: [":row", ":setting", "overridden", "typeClass"],
  classNames: ["form-kit__container", "form-kit__field"],

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
    this.element.removeEventListener("keydown", this._handleKeydown);
  },

  displayDescription: computed("componentType", function () {
    return this.componentType !== "bool";
  }),

  dirty: computed("buffered.value", "setting.value", function () {
    let bufferVal = this.buffered.get("value");
    let settingVal = this.setting?.value;

    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    const dirty = !deepEqual(bufferVal, settingVal);

    if (dirty) {
      this.siteSettingChangeTracker.add(this.setting);
    } else {
      this.siteSettingChangeTracker.remove(this.setting);
    }

    return dirty;
  }),

  preview: computed("setting", "buffered.value", function () {
    const setting = this.setting;
    const value = this.buffered.get("value");
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
    const value = this.buffered.get("value");
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
    } else if (setting.schema) {
      return {
        action: () => {
          this.router.transitionTo("admin.schema", setting.setting);
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

  disableControls: computed("setting.isSaving", function () {
    return !!this.setting.isSaving;
  }),

  update: action(async function () {
    if (this.setting.requiresConfirmation) {
      const confirm = await this.siteSettingChangeTracker.confirmChanges(
        this.setting
      );

      if (!confirm) {
        return;
      }
    }

    if (this.setting.affectsExistingUsers) {
      await this.siteSettingChangeTracker.configureBackfill(this.setting);
    }

    await this.save();
  }),

  save: action(async function () {
    try {
      this.setting.isSaving = true;

      await this._save();

      this.setting.validationMessage = null;
      this.buffered.applyChanges();

      if (this.setting.requiresReload) {
        this.siteSettingChangeTracker.refreshPage({
          [this.setting.setting]: this.setting.value,
        });
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = htmlSafe(errorString);
        }

        this.setting.validationMessage = errorString;
      } else {
        this.setting.validationMessage = i18n("generic_error");
      }
    } finally {
      this.setting.isSaving = false;
    }
  }),

  changeValueCallback: action(function (value) {
    this.buffered.set("value", value);
  }),

  setValidationMessage: action(function (message) {
    this.setting.validationMessage = message;
  }),

  cancel: action(function () {
    this.buffered.discardChanges();
    this.setting.validationMessage = null;
  }),

  resetDefault: action(function () {
    this.buffered.set("value", this.setting.default);
    this.setting.validationMessage = null;
  }),

  toggleSecret: action(function () {
    this.toggleProperty("isSecret");
  }),

  setDefaultValues: action(function () {
    this.buffered.set(
      "value",
      this.bufferedValues.concat(this.defaultValues).uniq().join("|")
    );
    this.setting.validationMessage = null;
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
