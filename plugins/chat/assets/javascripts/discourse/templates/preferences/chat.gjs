import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import Form from "discourse/components/form";
import SaveControls from "discourse/components/save-controls";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class Chat extends Component {
  @service chatAudioManager;

  get formData() {
    let emojis =
      this.args.controller.model.user_option.chat_quick_reactions_custom ||
      "heart|+1|smile";
    emojis = emojis.split("|");
    return {
      chat_enabled: this.args.controller.model.user_option.chat_enabled,
      chat_quick_reaction_type:
        this.args.controller.model.user_option.chat_quick_reaction_type,
      chat_quick_reactions_custom: emojis,
      only_chat_push_notifications:
        this.args.controller.model.user_option.only_chat_push_notifications,
      ignore_channel_wide_mention:
        this.args.controller.model.user_option.ignore_channel_wide_mention,
      chat_sound: this.args.controller.model.user_option.chat_sound,
    };
  }

  @action
  handleEmojiSet(index, field, value) {
    let newValue = [...field.value];
    newValue[index] = value;
    field.set(newValue);
  }

  @action
  handleChatSoundSet(sound, field) {
    if (sound) {
      this.chatAudioManager.play(sound);
    }
    field.set(sound);
  }

  @action
  handleSubmit(data) {
    // eslint-disable-next-line no-console
    console.log("reaction type", data.chat_quick_reaction_type);
    this.args.controller.model.set(
      "user_option.chat_quick_reaction_type",
      data.chat_quick_reaction_type
    );
    // eslint-disable-next-line no-console
    console.log("custom reactions", data.chat_quick_reactions_custom);
    this.args.controller.model.set(
      "user_option.chat_quick_reactions_custom",
      data.chat_quick_reactions_custom.join("|")
    );
    // eslint-disable-next-line no-console
    console.log("only push notifications", data.only_chat_push_notifications);
    this.args.controller.model.set(
      "user_option.only_chat_push_notifications",
      data.only_chat_push_notifications
    );
    // eslint-disable-next-line no-console
    console.log(
      "ignore channel wide mention",
      data.ignore_channel_wide_mention
    );
    this.args.controller.model.set(
      "user_option.chat_enabled",
      data.chat_enabled
    );
    // eslint-disable-next-line no-console
    console.log("chat enabled", data.chat_enabled);
    this.args.controller.model.set(
      "user_option.ignore_channel_wide_mention",
      data.ignore_channel_wide_mention
    );
    // eslint-disable-next-line no-console
    console.log("chat sound", data.chat_sound);
    this.args.controller.model.set("user_option.chat_sound", data.chat_sound);
    this.args.controller.save();
  }

  <template>
    <Form
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      as |form data|
    >
      <form.Field
        @title={{i18n "chat.enable"}}
        @name="chat_enabled"
        @format="large"
        as |field|
      >
        <field.Checkbox @value={{field.value}} />
      </form.Field>

      <form.Section @title={{i18n "chat.chat_notifications_title"}}>
        <form.Field
          @title={{i18n "chat.only_chat_push_notifications.title"}}
          @name="only_chat_push_notifications"
          @format="large"
          @description={{i18n "chat.only_chat_push_notifications.description"}}
          as |field|
        >
          <field.Checkbox @value={{field.value}} />
        </form.Field>
        <form.Field
          @title={{i18n "chat.ignore_channel_wide_mention.title"}}
          @name="ignore_channel_wide_mention"
          @format="large"
          as |field|
        >
          <field.Checkbox @value={{field.value}} />
        </form.Field>

        <form.Field
          @title={{i18n "chat.sound.title"}}
          @name="chat_sound"
          @format="large"
          @onSet={{this.handleChatSoundSet}}
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.chatSounds as |sound|}}
              <select.Option @value={{sound.value}}>
                {{sound.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

      </form.Section>
      <form.Section @title={{i18n "chat.personalization_title"}}>
        <form.Field
          @title={{i18n "chat.quick_reaction_type.title"}}
          @name="chat_quick_reaction_type"
          @format="large"
          as |field|
        >
          <field.RadioGroup @name="chat_quick_reaction_type" as |radioGroup|>
            {{#each @controller.chatQuickReactionTypes as |option|}}
              <radioGroup.Radio @value={{option.value}}>
                {{option.label}}
              </radioGroup.Radio>
            {{/each}}
          </field.RadioGroup>
        </form.Field>

        {{#if (eq data.chat_quick_reaction_type "custom")}}
          <form.Field
            @title={{i18n "chat.quick_reaction_type.title"}}
            @showTitle={{false}}
            @name="chat_quick_reactions_custom"
            @format="large"
            as |field|
          >
            <field.Custom>

              {{#each data.chat_quick_reactions_custom as |emoji index|}}
                <EmojiPicker
                  @emoji={{emoji}}
                  @btnClass="btn-default"
                  @context="chat_preferences"
                  @didSelectEmoji={{fn this.handleEmojiSet index field}}
                />
              {{/each}}
            </field.Custom>
          </form.Field>
        {{/if}}
      </form.Section>
      <form.Submit />
    </Form>

    {{!-- <div
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
    </div> --}}

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
}
