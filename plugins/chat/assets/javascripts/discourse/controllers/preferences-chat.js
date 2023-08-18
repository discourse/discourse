import Controller from "@ember/controller";
import { isTesting } from "discourse-common/config/environment";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { CHAT_SOUNDS } from "discourse/plugins/chat/discourse/services/chat-audio-manager";
import { inject as service } from "@ember/service";

const CHAT_ATTRS = [
  "chat_enabled",
  "only_chat_push_notifications",
  "ignore_channel_wide_mention",
  "chat_sound",
  "chat_email_frequency",
  "chat_header_indicator_preference",
  "chat_separate_sidebar_mode",
];

const EMAIL_FREQUENCY_OPTIONS = [
  { name: I18n.t("chat.email_frequency.never"), value: "never" },
  { name: I18n.t("chat.email_frequency.when_away"), value: "when_away" },
];

export const HEADER_INDICATOR_PREFERENCE_NEVER = "never";
export const HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS = "dm_and_mentions";
export const HEADER_INDICATOR_PREFERENCE_ALL_NEW = "all_new";
const HEADER_INDICATOR_OPTIONS = [
  {
    name: I18n.t("chat.header_indicator_preference.all_new"),
    value: HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  },
  {
    name: I18n.t("chat.header_indicator_preference.dm_and_mentions"),
    value: HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  },
  {
    name: I18n.t("chat.header_indicator_preference.never"),
    value: HEADER_INDICATOR_PREFERENCE_NEVER,
  },
];

const CHAT_SEPARATE_SIDEBAR_MODE_OPTIONS = [
  {
    name: I18n.t("admin.site_settings.chat_separate_sidebar_mode.always"),
    value: "always",
  },
  {
    name: I18n.t("admin.site_settings.chat_separate_sidebar_mode.fullscreen"),
    value: "fullscreen",
  },
  {
    name: I18n.t("admin.site_settings.chat_separate_sidebar_mode.never"),
    value: "never",
  },
];

export default class PreferencesChatController extends Controller {
  @service chatAudioManager;
  @service siteSettings;

  subpageTitle = I18n.t("chat.admin.title");

  emailFrequencyOptions = EMAIL_FREQUENCY_OPTIONS;
  headerIndicatorOptions = HEADER_INDICATOR_OPTIONS;
  chatSeparateSidebarModeOptions = CHAT_SEPARATE_SIDEBAR_MODE_OPTIONS;

  get chatSeparateSidebarMode() {
    const mode = this.model.get("user_option.chat_separate_sidebar_mode");
    if (mode === "default") {
      return this.siteSettings.chat_separate_sidebar_mode;
    } else {
      return mode;
    }
  }

  @discourseComputed
  chatSounds() {
    return Object.keys(CHAT_SOUNDS).map((value) => {
      return { name: I18n.t(`chat.sounds.${value}`), value };
    });
  }

  @action
  onChangeChatSound(sound) {
    if (sound) {
      this.chatAudioManager.playImmediately(sound);
    }
    this.model.set("user_option.chat_sound", sound);
  }

  @action
  save() {
    this.set("saved", false);
    return this.model
      .save(CHAT_ATTRS)
      .then(() => {
        this.set("saved", true);
        if (!isTesting()) {
          location.reload();
        }
      })
      .catch(popupAjaxError);
  }
}
