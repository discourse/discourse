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
import { SITE_SETTING_REQUIRES_CONFIRMATION_TYPES } from "discourse/lib/constants";
import { splitString } from "discourse/lib/utilities";
import { deepEqual } from "discourse-common/lib/object";
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
  "default_hide_profile",
  "default_hide_presence",
  "default_other_new_topic_duration_minutes",
  "default_other_auto_track_topics_after_msecs",
  "default_other_notification_level_when_replying",
  "default_other_external_links_in_new_tab",
  "default_other_enable_quoting",
  "default_other_enable_smart_lists",
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

const ACRONYMS = new Set([
  "acl",
  "ai",
  "api",
  "bg",
  "cdn",
  "cors",
  "cta",
  "dm",
  "eu",
  "faq",
  "fg",
  "ga",
  "gb",
  "gtm",
  "hd",
  "http",
  "https",
  "iam",
  "id",
  "imap",
  "ip",
  "jpg",
  "json",
  "kb",
  "mb",
  "oidc",
  "pm",
  "png",
  "pop3",
  "s3",
  "smtp",
  "svg",
  "tl",
  "tl0",
  "tl1",
  "tl2",
  "tl3",
  "tl4",
  "tld",
  "txt",
  "url",
  "ux",
]);

const MIXED_CASE = new Map([
  ["adobe analytics", "Adobe Analytics"],
  ["android", "Android"],
  ["chinese", "Chinese"],
  ["discord", "Discord"],
  ["discourse", "Discourse"],
  ["discourse connect", "Discourse Connect"],
  ["discourse discover", "Discourse Discover"],
  ["discourse narrative bot", "Discourse Narrative Bot"],
  ["facebook", "Facebook"],
  ["github", "GitHub"],
  ["google", "Google"],
  ["gravatar", "Gravatar"],
  ["gravatars", "Gravatars"],
  ["ios", "iOS"],
  ["japanese", "Japanese"],
  ["linkedin", "LinkedIn"],
  ["oauth2", "OAuth2"],
  ["opengraph", "OpenGraph"],
  ["powered by discourse", "Powered by Discourse"],
  ["tiktok", "TikTok"],
  ["tos", "ToS"],
  ["twitter", "Twitter"],
  ["vimeo", "Vimeo"],
  ["wordpress", "WordPress"],
  ["youtube", "YouTube"],
]);

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

    return !deepEqual(bufferVal, settingVal);
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
    const setting = this.setting?.setting;
    const label = this.setting?.label;
    const name = label || setting.replace(/\_/g, " ");

    const formattedName = (name.charAt(0).toUpperCase() + name.slice(1))
      .split(" ")
      .map((word) =>
        ACRONYMS.has(word.toLowerCase()) ? word.toUpperCase() : word
      )
      .map((word) => {
        if (word.endsWith("s")) {
          const singular = word.slice(0, -1).toLowerCase();
          return ACRONYMS.has(singular) ? singular.toUpperCase() + "s" : word;
        }
        return word;
      })
      .join(" ");

    return MIXED_CASE[Symbol.iterator]().reduce(
      (acc, [key, value]) => acc.replaceAll(new RegExp(key, "gi"), value),
      formattedName
    );
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

  disableSaveButton: computed("validationMessage", function () {
    return !!this.validationMessage;
  }),

  confirmChanges(settingKey) {
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

  update: action(async function () {
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
  }),

  setUpdateExistingUsers: action(function (value) {
    this.updateExistingUsers = value;
  }),

  save: action(async function () {
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
        this.set("validationMessage", i18n("generic_error"));
      }
    }
  }),

  changeValueCallback: action(function (value) {
    this.set("buffered.value", value);
  }),

  setValidationMessage: action(function (message) {
    this.set("validationMessage", message);
  }),

  cancel: action(function () {
    this.rollbackBuffer();
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
