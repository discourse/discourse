import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { translateModKey } from "discourse/lib/utilities";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
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

  get formData() {
    const userOption = this.model.get("user_option");
    const customEmojis = this.chatQuickReactionsCustom;

    // Handle chat_separate_sidebar_mode default value
    let separateSidebarMode = userOption.chat_separate_sidebar_mode;
    if (separateSidebarMode === "default") {
      separateSidebarMode = this.siteSettings.chat_separate_sidebar_mode;
    }

    return {
      chat_enabled: userOption.chat_enabled || false,
      chat_quick_reaction_type:
        userOption.chat_quick_reaction_type || "frequent",
      chat_quick_reactions_custom_0: customEmojis[0] || "",
      chat_quick_reactions_custom_1: customEmojis[1] || "",
      chat_quick_reactions_custom_2: customEmojis[2] || "",
      only_chat_push_notifications:
        userOption.only_chat_push_notifications || false,
      ignore_channel_wide_mention:
        userOption.ignore_channel_wide_mention || false,
      chat_sound: userOption.chat_sound || null,
      chat_header_indicator_preference:
        userOption.chat_header_indicator_preference ||
        HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
      chat_separate_sidebar_mode: separateSidebarMode || "never",
      chat_send_shortcut: userOption.chat_send_shortcut || "enter",
    };
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
  onSetChatSound(value, { set }) {
    // Play audio preview
    if (value) {
      this.chatAudioManager.play(value);
    }
    // Update form data
    set("chat_sound", value);
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
  async saveForm(data) {
    this.set("saved", false);

    // Map flat FormKit data back to nested model structure
    const userOption = this.model.get("user_option");

    userOption.set("chat_enabled", data.chat_enabled || false);
    userOption.set(
      "chat_quick_reaction_type",
      data.chat_quick_reaction_type || "frequent"
    );

    // Combine emoji array back to pipe-separated string
    const customEmojis = [
      data.chat_quick_reactions_custom_0 || "",
      data.chat_quick_reactions_custom_1 || "",
      data.chat_quick_reactions_custom_2 || "",
    ].filter(Boolean);
    userOption.set(
      "chat_quick_reactions_custom",
      customEmojis.length > 0 ? customEmojis.join("|") : null
    );

    userOption.set(
      "only_chat_push_notifications",
      data.only_chat_push_notifications || false
    );
    userOption.set(
      "ignore_channel_wide_mention",
      data.ignore_channel_wide_mention || false
    );
    userOption.set("chat_sound", data.chat_sound || null);
    userOption.set(
      "chat_header_indicator_preference",
      data.chat_header_indicator_preference ||
        HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS
    );
    userOption.set(
      "chat_separate_sidebar_mode",
      data.chat_separate_sidebar_mode || "never"
    );
    userOption.set("chat_send_shortcut", data.chat_send_shortcut || "enter");

    try {
      await this.model.save(CHAT_ATTRS);
      this.set("saved", true);
      if (!isTesting()) {
        location.reload();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
