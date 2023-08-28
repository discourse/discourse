import { isNone } from "@ember/utils";
import { fmt, propertyNotEqual } from "discourse/lib/computed";
import { alias, oneWay } from "@ember/object/computed";
import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import { ajax } from "discourse/lib/ajax";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";
import { warn } from "@ember/debug";
import { action } from "@ember/object";
import { splitString } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import SiteSettingDefaultCategoriesModal from "../components/modal/site-setting-default-categories";

const CUSTOM_TYPES = [
  "bool",
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
  site: service(),
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

    return bufferVal.toString() !== settingVal.toString();
  },

  @discourseComputed("setting", "buffered.value")
  preview(setting, value) {
    // A bit hacky, but allows us to use helpers
    if (setting.setting === "category_style") {
      const category = this.site.get("categories.firstObject");
      if (category) {
        return categoryLinkHTML(category, { categoryStyle: value });
      }
    }

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

  @action
  async update() {
    const key = this.buffered.get("setting");

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
  cancel() {
    this.rollbackBuffer();
  },

  @action
  resetDefault() {
    this.set("buffered.value", this.get("setting.default"));
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
