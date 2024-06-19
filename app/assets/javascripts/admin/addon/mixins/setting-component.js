import { warn } from "@ember/debug";
import { action } from "@ember/object";
import { alias, oneWay } from "@ember/object/computed";
import Mixin from "@ember/object/mixin";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isNone } from "@ember/utils";
import { Promise } from "rsvp";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import { ajax } from "discourse/lib/ajax";
import { fmt, propertyNotEqual } from "discourse/lib/computed";
import { SITE_SETTING_REQUIRES_CONFIRMATION_TYPES } from "discourse/lib/constants";
import { splitString } from "discourse/lib/utilities";
import { deepEqual } from "discourse-common/lib/object";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
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
];

const AUTO_REFRESH_ON_SAVE = ["logo", "logo_small", "large_icon"];

const DEFAULT_USER_PREFERENCES = [
  "default_email_digest_frequency",
  "default_include_tl0_in_digests",
  "default_email_level",
  "default_email_messages_level",
  "default_email_mailing_list_mode",
  "default_email_mailing_list_mode_frequency",
  "default_email_previous_replies",
  "default_email_in_reply_to",
  "default_hide_profile_and_presence",
  "default_other_new_topic_duration_minutes",
  "default_other_auto_track_topics_after_msecs",
  "default_other_notification_level_when_replying",
  "default_other_external_links_in_new_tab",
  "default_other_enable_quoting",
  "default_other_enable_defer",
  "default_other_dynamic_favicon",
  "default_other_like_notification_frequency",
  "default_other_skip_new_user_tips",
  "default_topics_automatic_unpin",
  "default_categories_watching",
  "default_categories_tracking",
  "default_categories_muted",
  "default_categories_watching_first_post",
  "default_categories_normal",
  "default_tags_watching",
  "default_tags_tracking",
  "default_tags_muted",
  "default_tags_watching_first_post",
  "default_text_size",
  "default_title_count_mode",
  "default_navigation_menu_categories",
  "default_navigation_menu_tags",
  "default_sidebar_link_to_filtered_list",
  "default_sidebar_show_count_of_new_items",
];

export default Mixin.create({
  modal: service(),
  router: service(),
  site: service(),
  dialog: service(),
  attributeBindings: ["setting.setting:data-setting"],
  classNameBindings: [":row", ":setting", "overridden", "typeClass"],
  validationMessage: null,
  setting: null,

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

  @discourseComputed("buffered.value", "setting.value")
  dirty(bufferVal, settingVal) {
    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    return !deepEqual(bufferVal, settingVal);
  },

  @discourseComputed("setting", "buffered.value")
  preview(setting, value) {
    const preview = setting.preview;
    if (preview) {
      const escapedValue = preview.replace(/\{\{value\}\}/g, value);
      return htmlSafe(`<div class='preview'>${escapedValue}</div>`);
    }
  },

  @discourseComputed("componentType")
  typeClass(componentType) {
    return componentType.replace(/\_/g, "-");
  },

  @discourseComputed("setting.setting", "setting.label")
  settingName(setting, label) {
    return label || setting.replace(/\_/g, " ");
  },

  @discourseComputed("type")
  componentType(type) {
    return CUSTOM_TYPES.includes(type) ? type : "string";
  },

  @discourseComputed("setting")
  type(setting) {
    if (setting.type === "list" && setting.list_type) {
      return `${setting.list_type}_list`;
    }

    return setting.type;
  },

  @discourseComputed("setting.anyValue")
  allowAny(anyValue) {
    return anyValue !== false;
  },

  @discourseComputed("buffered.value")
  bufferedValues(value) {
    return splitString(value, "|");
  },

  @discourseComputed("setting.defaultValues")
  defaultValues(value) {
    return splitString(value, "|");
  },

  @discourseComputed("defaultValues", "bufferedValues")
  defaultIsAvailable(defaultValues, bufferedValues) {
    return (
      defaultValues.length > 0 &&
      !defaultValues.every((value) => bufferedValues.includes(value))
    );
  },

  @discourseComputed("setting")
  settingEditButton(setting) {
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
        icon: "pencil-alt",
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
        icon: "pencil-alt",
      };
    }
  },

  confirmChanges(settingKey) {
    return new Promise((resolve) => {
      // Fallback is needed in case the setting does not have a custom confirmation
      // prompt/confirm defined.
      this.dialog.alert({
        message: I18n.t(
          `admin.site_settings.requires_confirmation_messages.${settingKey}.prompt`,
          {
            translatedFallback: I18n.t(
              "admin.site_settings.requires_confirmation_messages.default.prompt"
            ),
          }
        ),
        buttons: [
          {
            label: I18n.t(
              `admin.site_settings.requires_confirmation_messages.${settingKey}.confirm`,
              {
                translatedFallback: I18n.t(
                  "admin.site_settings.requires_confirmation_messages.default.confirm"
                ),
              }
            ),
            class: "btn-primary",
            action: () => resolve(true),
          },
          {
            label: I18n.t("no_value"),
            class: "btn-default",
            action: () => resolve(false),
          },
        ],
      });
    });
  },

  @action
  async update() {
    const key = this.buffered.get("setting");

    let confirm = true;
    if (
      this.buffered.get("requires_confirmation") ===
      SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple
    ) {
      confirm = await this.confirmChanges(key);
    }

    if (!confirm) {
      this.cancel();
      return;
    }

    if (!DEFAULT_USER_PREFERENCES.includes(key)) {
      await this.save();
      return;
    }

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
      this.save();
    } else {
      await this.save();
    }
  },

  @action
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  },

  @action
  async save() {
    try {
      await this._save();

      this.set("validationMessage", null);
      this.commitBuffer();
      if (AUTO_REFRESH_ON_SAVE.includes(this.setting.setting)) {
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
        this.set("validationMessage", I18n.t("generic_error"));
      }
    }
  },

  @action
  changeValueCallback(value) {
    this.set("buffered.value", value);
  },

  @action
  cancel() {
    this.rollbackBuffer();
  },

  @action
  resetDefault() {
    this.set("buffered.value", this.setting.default);
  },

  @action
  toggleSecret() {
    this.toggleProperty("isSecret");
  },

  @action
  setDefaultValues() {
    this.set(
      "buffered.value",
      this.bufferedValues.concat(this.defaultValues).uniq().join("|")
    );
    return false;
  },

  @bind
  _handleKeydown(event) {
    if (
      event.key === "Enter" &&
      event.target.classList.contains("input-setting-string")
    ) {
      this.save();
    }
  },

  async _save() {
    warn("You should define a `_save` method", {
      id: "discourse.setting-component.missing-save",
    });
  },
});
