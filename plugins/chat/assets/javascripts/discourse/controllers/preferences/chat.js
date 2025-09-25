import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { CHAT_SOUNDS } from "discourse/plugins/chat/discourse/services/chat-audio-manager";

const CHAT_ATTRS = [
  "chat_enabled",
  "only_chat_push_notifications",
  "ignore_channel_wide_mention",
  "show_thread_title_prompts",
  "chat_sound",
  "chat_email_frequency",
  "chat_header_indicator_preference",
  "chat_separate_sidebar_mode",
  "chat_send_shortcut",
  "chat_quick_reaction_type",
  "chat_quick_reactions_custom",
];

export const CHAT_QUICK_REACTIONS_CUSTOM_DEFAULT = "heart|+1|smile";

export const HEADER_INDICATOR_PREFERENCE_NEVER = "never";
export const HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS = "dm_and_mentions";
export const HEADER_INDICATOR_PREFERENCE_ALL_NEW = "all_new";
export const HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS = "only_mentions";

export default class PreferencesChatController extends Controller {
  @service chatAudioManager;
  @service siteSettings;

  subpageTitle = i18n("chat.admin.title");

  chatQuickReactionTypes = [
    {
      label: i18n("chat.quick_reaction_type.options.frequent"),
      value: "frequent",
    },
    {
      label: i18n("chat.quick_reaction_type.options.custom"),
      value: "custom",
    },
  ];

  chatSendShortcutOptions = [
    {
      label: i18n("chat.send_shortcut.enter.label"),
      value: "enter",
      description: i18n("chat.send_shortcut.enter.description"),
    },
    {
      label: i18n("chat.send_shortcut.meta_enter.label", {
        meta_key: translateModKey(PLATFORM_KEY_MODIFIER),
      }),
      value: "meta_enter",
      description: i18n("chat.send_shortcut.meta_enter.description"),
    },
  ];

  emailFrequencyOptions = [
    { name: i18n("chat.email_frequency.never"), value: "never" },
    { name: i18n("chat.email_frequency.when_away"), value: "when_away" },
  ];

  headerIndicatorOptions = [
    {
      name: i18n("chat.header_indicator_preference.all_new"),
      value: HEADER_INDICATOR_PREFERENCE_ALL_NEW,
    },
    {
      name: i18n("chat.header_indicator_preference.dm_and_mentions"),
      value: HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
    },
    {
      name: i18n("chat.header_indicator_preference.only_mentions"),
      value: HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
    },
    {
      name: i18n("chat.header_indicator_preference.never"),
      value: HEADER_INDICATOR_PREFERENCE_NEVER,
    },
  ];

  chatSeparateSidebarModeOptions = [
    {
      name: i18n("admin.site_settings.chat_separate_sidebar_mode.always"),
      value: "always",
    },
    {
      name: i18n("admin.site_settings.chat_separate_sidebar_mode.fullscreen"),
      value: "fullscreen",
    },
    {
      name: i18n("admin.site_settings.chat_separate_sidebar_mode.never"),
      value: "never",
    },
  ];

  get chatSeparateSidebarMode() {
    const mode = this.model.get("user_option.chat_separate_sidebar_mode");
    if (mode === "default") {
      return this.siteSettings.chat_separate_sidebar_mode;
    } else {
      return mode;
    }
  }

  get chatSendShortcut() {
    return this.model.get("user_option.chat_send_shortcut");
  }

  get chatQuickReactionsCustom() {
    const emojis =
      this.model.get("user_option.chat_quick_reactions_custom") ||
      CHAT_QUICK_REACTIONS_CUSTOM_DEFAULT;
    return emojis.split("|");
  }

  @discourseComputed
  chatSounds() {
    return Object.keys(CHAT_SOUNDS).map((value) => {
      return { name: i18n(`chat.sounds.${value}`), value };
    });
  }

  @action
  onChangeChatSound(sound) {
    if (sound) {
      this.chatAudioManager.play(sound);
    }
    this.model.set("user_option.chat_sound", sound);
  }

  @action
  onChangeQuickReactionType(value) {
    this.model.set("user_option.chat_quick_reaction_type", value);
    if (value === "custom") {
      this.model.set(
        "user_option.chat_quick_reactions_custom",
        this.chatQuickReactionsCustom.join("|")
      );
    }
  }

  @action
  didSelectEmoji(index, selected) {
    let emoji = this.chatQuickReactionsCustom;
    emoji[index] = selected;
    this.model.set("user_option.chat_quick_reactions_custom", emoji.join("|"));
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
