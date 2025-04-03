import { Input } from "@ember/component";
import { array, concat, fn, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { eq } from "truth-helpers";
import EmojiPicker from "discourse/components/emoji-picker";
import SaveControls from "discourse/components/save-controls";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <label class="control-label">{{i18n "chat.title_capitalized"}}</label>

    <div
      class="control-group chat-setting"
      data-setting-name="user_chat_enabled"
    >
      <label class="controls">
        <Input
          id="user_chat_enabled"
          @type="checkbox"
          @checked={{@controller.model.user_option.chat_enabled}}
        />
        {{i18n "chat.enable"}}
      </label>
    </div>

    <fieldset
      class="control-group chat-setting"
      data-setting-name="user_chat_quick_reaction_type"
    >
      <legend class="control-label">{{i18n
          "chat.quick_reaction_type.title"
        }}</legend>
      <div class="radio-group">
        {{#each @controller.chatQuickReactionTypes as |option|}}
          <div class="radio-group-option">
            <label class="controls">
              <input
                type="radio"
                name="user_chat_quick_reaction_type"
                id={{concat "user_chat_quick_reaction_type_" option.value}}
                value={{option.value}}
                checked={{eq
                  @controller.model.user_option.chat_quick_reaction_type
                  option.value
                }}
                {{on
                  "change"
                  (withEventValue @controller.onChangeQuickReactionType)
                }}
              />
              {{option.label}}
            </label>
          </div>
        {{/each}}
      </div>

      {{#if
        (eq @controller.model.user_option.chat_quick_reaction_type "custom")
      }}
        <div class="controls tracking-controls emoji-pickers">
          {{#each (array 0 1 2) as |index|}}
            <EmojiPicker
              @emoji={{get @controller.chatQuickReactionsCustom index}}
              @didSelectEmoji={{fn @controller.didSelectEmoji index}}
              @context="chat_preferences"
            />
          {{/each}}
        </div>
      {{/if}}
    </fieldset>

    <div
      class="control-group chat-setting"
      data-setting-name="user_chat_only_push_notifications"
    >
      <label class="controls">
        <Input
          id="user_chat_only_push_notifications"
          @type="checkbox"
          @checked={{@controller.model.user_option.only_chat_push_notifications}}
        />
        {{i18n "chat.only_chat_push_notifications.title"}}
      </label>
      <span class="control-instructions">
        {{i18n "chat.only_chat_push_notifications.description"}}
      </span>
    </div>

    <div
      class="control-group chat-setting"
      data-setting-name="user_chat_ignore_channel_wide_mention"
    >
      <label class="controls">
        <Input
          id="user_chat_ignore_channel_wide_mention"
          @type="checkbox"
          @checked={{@controller.model.user_option.ignore_channel_wide_mention}}
        />
        {{i18n "chat.ignore_channel_wide_mention.title"}}
      </label>
      <span class="control-instructions">
        {{i18n "chat.ignore_channel_wide_mention.description"}}
      </span>
    </div>

    <div
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_sounds"
    >
      <label for="user_chat_sounds">{{i18n "chat.sound.title"}}</label>
      <ComboBox
        @options={{hash none="chat.sounds.none"}}
        @valueProperty="value"
        @content={{@controller.chatSounds}}
        @value={{@controller.model.user_option.chat_sound}}
        @id="user_chat_sounds"
        @onChange={{@controller.onChangeChatSound}}
      />
    </div>

    <div
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_email_frequency"
    >
      <label for="user_chat_email_frequency">
        {{i18n "chat.email_frequency.title"}}
      </label>
      <ComboBox
        @valueProperty="value"
        @content={{@controller.emailFrequencyOptions}}
        @value={{@controller.model.user_option.chat_email_frequency}}
        @id="user_chat_email_frequency"
        @onChange={{fn
          (mut @controller.model.user_option.chat_email_frequency)
        }}
      />
      {{#if
        (eq @controller.model.user_option.chat_email_frequency "when_away")
      }}
        <div class="control-instructions">
          {{i18n "chat.email_frequency.description"}}
        </div>
      {{/if}}
    </div>

    <div
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_header_indicator_preference"
    >
      <label for="user_chat_header_indicator_preference">
        {{i18n "chat.header_indicator_preference.title"}}
      </label>
      <ComboBox
        @valueProperty="value"
        @content={{@controller.headerIndicatorOptions}}
        @value={{@controller.model.user_option.chat_header_indicator_preference}}
        @id="user_chat_header_indicator_preference"
        @onChange={{fn
          (mut @controller.model.user_option.chat_header_indicator_preference)
        }}
      />
    </div>

    <div
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_separate_sidebar_mode"
    >
      <label for="user_chat_separate_sidebar_mode">
        {{i18n "chat.separate_sidebar_mode.title"}}
      </label>

      <ComboBox
        @valueProperty="value"
        @content={{@controller.chatSeparateSidebarModeOptions}}
        @value={{@controller.chatSeparateSidebarMode}}
        @id="user_chat_separate_sidebar_mode"
        @onChange={{fn
          (mut @controller.model.user_option.chat_separate_sidebar_mode)
        }}
      />
    </div>

    <div
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_send_shortcut"
    >
      <div class="radio-group">
        {{#each @controller.chatSendShortcutOptions as |option|}}
          <div class="radio-group-option">
            <label class="controls">
              <input
                type="radio"
                name="chat_send_shortcut"
                id={{concat "chat_send_shortcut_" option.value}}
                value={{option.value}}
                checked={{eq
                  @controller.model.user_option.chat_send_shortcut
                  option.value
                }}
                {{on
                  "change"
                  (withEventValue
                    (fn (mut @controller.model.user_option.chat_send_shortcut))
                  )
                }}
              />
              {{option.label}}
            </label>
            <span class="control-instructions">
              {{option.description}}
            </span>
          </div>
        {{/each}}
      </div>
    </div>

    <SaveControls
      @id="user_chat_preference_save"
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
