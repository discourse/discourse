import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
  HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import {
  CHAT_SOUNDS,
  normalizeChatSoundName,
} from "discourse/plugins/chat/discourse/services/chat-audio-manager";

export default class ChatNotifications extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.chat_enabled && args.model?.user_option?.chat_enabled;
  }

  @service chatAudioManager;

  get model() {
    return this.args.outletArgs.model;
  }

  get userOption() {
    return this.model.user_option;
  }

  get chatSounds() {
    return Object.keys(CHAT_SOUNDS).map((value) => ({
      name: i18n(`chat.sounds.${value}`),
      value,
    }));
  }

  get chatSound() {
    return normalizeChatSoundName(this.userOption.chat_sound);
  }

  get headerIndicatorOptions() {
    return [
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
  }

  @action
  setUserOption(key, value) {
    this.model.set(`user_option.${key}`, value);
  }

  @action
  setChatSound(sound) {
    if (sound) {
      this.chatAudioManager?.play(sound, { throttle: false });
    }

    this.model.set("user_option.chat_sound", sound ?? null);
  }

  <template>
    <div class="control-group chat-notifications">
      <label class="control-label">{{i18n
          "chat.chat_notifications_title"
        }}</label>

      <PreferenceCheckbox
        @labelKey="chat.ignore_channel_wide_mention.title"
        @checked={{this.userOption.ignore_channel_wide_mention}}
        data-setting-name="chat-ignore-channel-wide-mention"
        class="pref-chat-ignore-channel-wide-mention"
      />

      <div class="controls controls-dropdown">
        <label>{{i18n "chat.sound.title"}}</label>
        <ComboBox
          @valueProperty="value"
          @content={{this.chatSounds}}
          @value={{this.chatSound}}
          @options={{hash none="chat.sounds.none"}}
          @onChange={{this.setChatSound}}
          class="chat-sound"
        />
      </div>

      <div class="controls controls-dropdown">
        <label>{{i18n "chat.header_indicator_preference.title"}}</label>
        <ComboBox
          @valueProperty="value"
          @content={{this.headerIndicatorOptions}}
          @value={{this.userOption.chat_header_indicator_preference}}
          @onChange={{fn this.setUserOption "chat_header_indicator_preference"}}
          class="chat-header-indicator-preference"
        />
      </div>
    </div>
  </template>
}
